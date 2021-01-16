; Programme pour installer une chaŒne d'environnement personnalis‚e
; * … la variable TOS the_env $4be
; * au GEM, via injection dans la basepage
;
; La taille maximale est de MAX_ENV_SIZE, elle est faite pour que
; sur une disquette, ‡a remplisse un cluster de 1024 octets.
;
; Utilisation:
; setenv.tos <fichier>
;   Charge le fichier fichier comme environnement. Il doit contenir
;   une ligne par variable, formatt‚ VARIABLE=VALEUR\r\n et se terminer
;   par une ligne vide.
;
; setenv.tos
;   Affiche l'environnement sp‚cifi‚ par la variable "the_env", avec
;   retour chariot … la fin de chaque variable.
;   Si la variable ne contient aucun environnement, charge
;   l'environnement depuis le fichier setenv.txt (qui doit se trouver
;   dans le r‚pertoire "courant", quoi que cela veuille dire).
; 
; Vinz/MPS, Janvier 2021
; <vincent.barrilliot@laposte.net>
; Domaine Publique

	OUTPUT	setenv.prg

DEBUG	EQU 0
	IFNE DEBUG
	OPT	D+,X+
	ELSE
	OPT	D-,S-,X-
	ENDC


****************************************************
*                  MACROS                          *
****************************************************
Supexec	MACRO
	move.l	\1,-(sp)
	move.w	#38,-(sp)
	trap	#14 ; Supexec
	addq.l	#6,sp
	ENDM

Fopen	MACRO
	move.w	\2,-(sp)
	move.l	\1,-(sp)
	move.w	#61,-(sp)	; Fopen
	trap	#1
	addq.l	#8,sp
	ENDM

Fread	MACRO	
	pea	\3
	move.l	\2,-(sp)
	move.w	\1,-(sp)
	move.w	#63,-(sp)
	trap	#1	; Fread
	lea	12(sp),sp
	ENDM

Fclose	MACRO
	move.w	\1,-(sp)
	move.w	#62,-(sp)
	trap	#1	; Fclose
	addq.l	#4,sp
	ENDM

Cconws	MACRO
	move.l	\1,-(sp)
	move.w	#9,-(sp)
	trap	#1	; Cconws
	addq.l	#6,sp
	ENDM

Pterm0	MACRO
	clr.w	-(sp) 	; Pterm0
	trap	#1
	ENDM

Ptermres	MACRO
	clr.w	-(sp)
	move.l	\1,-(sp)
	move.w	#49,-(sp)
	trap	#1
	ENDM

****************************************************
*                 DEFINITIONS                      *
****************************************************

the_env		EQU	$4be ; variable document‚e du TOS
exec_os		EQU	$4fe ; le GEM
MAX_ENV_SIZE	EQU	564  ; taille maxi de la chaine d'environnement

****************************************************
*                 PARTIE RESIDENTE                 *
****************************************************

	SECTION TEXT
start	bra	main
new_exec_os
	move.l	4(sp),a0 ; basepage
	; On r‚‚crit simplement le pointeur vers la chaŒne d'environnement
	move.l	#env,44(a0)
	move.l	old_exec_os(pc),a1
	jmp	(a1)
old_exec_os	dc.l	0
env	ds.b	MAX_ENV_SIZE ; c'est ‡a qu'on donnera au TOS
end

****************************************************
*               PARTIE NON-RESIDENTE               *
****************************************************

	EVEN	
main	movea.l	4(sp),a5   ; BASEPAGE
	
	; Message … l'utilisateur
	move.l	#msg,a6
	bsr	cconws_a6

	; Regarde si un argument est donn‚ en ligne de commande
	lea	$80(a5),a5 	; a5:ligne de commande
	moveq	#0,d5
	move.b	(a5)+,d5 	; d5: longueur ligne de commande
	beq.s	nocmdline
	clr.b	1(a5,d5)	; termine la ligne de commande
	bra.s	loadenv

nocmdline ; pas de ligne de commande, affiche environnment si existant
	; sinon charge depuis setenv.txt
	bsr	affiche
	bra.s	abandon
	
affiche	; afficher l'environnement point‚ par $4be
	Supexec	#readenv
	tst.l	d0
	beq.s	loaddefaultenv  ; pas d'environnement, on va charger le notre
	movea.l	d0,a3
	movea.l	a3,a4
.boucle	tst.b	(a4)+	; cherche fin de la chaine
	bne.s	.boucle
	move.l	a3,a6
	bsr	cconws_a6
	move.l	#crlf,a6
	bsr	cconws_a6
	movea.l	a4,a3
	tst.b	(a3)	; deuxiŠme null = fin
	bne.s	.boucle
	rts	
	
	
loaddefaultenv
	move.l	#envtxt,a5
loadenv	; Charge l'environement depuis le fichier dont le nom est en a5
	; Ouvre le fichier
	Fopen	a5,#1	; ouvre fichier texte en lecture seule
	tst.w	d0
	bpl.s	ouvert
	; fichier pas trouv‚
	move.b	#' ',separat ; adapte la chaŒne pour la sortie
	move.l	#envtxt,a6
	bsr	cconws_a6
abandon	Pterm0

ouvert	; le fichier est ouvert, lit le contenu
	Fread	d0,#MAX_ENV_SIZE,env
	move.w	d0,d7	; d7: longueur du fichier
	Fclose	d0
	tst.w	d7
	beq.s	abandon ; si le fichier est vide on ne fait rien
	; remplace les crlf par des octets nuls
	lea	env,a1
	movea.l	a1,a2
	move.w	d7,d1
	subq.w	#1,d7 ; pour le dbra
boucle	move.b	(a1)+,d2
	cmpi.b	#$a,d2
	beq.s	ignore
	cmpi.b	#$d,d2
	bne.s	paslf
	clr.b	d2
paslf	move.b	d2,(a2)+
ignore	dbra	d7,boucle
	; assure que le dernier ‚tait termin‚ par null
	tst.b	d2	
	beq.s	dernierdejanul
	clr.b	(a2)+
dernierdejanul
	; ajoute le null final (pour avoir double null)
	clr.b	(a2)+
	suba.l	#start,a2	; a2: octets … garder

	; installe l'environnement
	Supexec	#installe

	; affiche des informations sur ce qu'on a fait
	move.l	a5,a6
	bsr	cconws_a6
	move.l	#msgcharge,a6
	bsr	cconws_a6
	bsr	affiche
			
	; garde r‚sident
	move.l	#$100,d2 ; taille de la BASEPAGE
	add.l	#end,d2
	sub.l	#start,d2	
	Ptermres	d2

installe
	move.l	#env,the_env.w
	move.l	exec_os.w,old_exec_os
	move.l	#new_exec_os,exec_os
	rts

readenv	move.l	the_env.w,d0
	rts

cconws_a6	Cconws	a6
	rts
	
	SECTION DATA
envtxt	dc.b	"setenv.txt"
separat	dc.b	0
failed	dc.b	"non trouv‚ !"
crlf	dc.b	$a,$d,0
msg	dc.b	27,"pSETENV 1.0",$a,$d,27,"q",0
msgcharge	dc.b	" charg‚.",$a,$d,0