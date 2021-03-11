; Programme pour installer une chaŒne d'environnement personnalis‚e
; * … la variable TOS the_env $4be
; * au GEM, via injection dans la basepage du programme appel‚ par
;   le bios via exec_os
;;
; Utilisation:
; setenv.prg <fichier>
;   Charge le fichier fichier comme environnement. Il doit contenir
;   une ligne par variable, formatt‚ VARIABLE=VALEUR\r\n.
;
; setenv.prg
;   Charge l'environnement depuis le fichier setenv.txt (qui doit se
;   trouver dans le r‚pertoire "courant", quoi que cela veuille dire).
;
; Vinz/MPS, Mars 2021
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

the_env	EQU $4be	; variable document‚e du TOS
exec_os	EQU $4fe	; le GEM


****************************************************
*                 PARTIE RESIDENTE                 *
****************************************************

	SECTION TEXT
start	bra	main

handle	dc.l	1	; handle du fichier … charger
msgcharge	dc.b	" charg‚!",$a,$d,0
msgvide	dc.b	" vide!"
crlf	dc.b	$a,$d,0
	EVEN


cconws_a6	; affiche la chaŒne en a6
	Cconws	a6
	rts

	
lit	; partie … garder pour ne pas que ‡a se chie dessus
	; A partir du moment o— arrive ici, il faut consid‚rer que
	; tout ce qui est aprŠs "env" est effac‚
	trap	#1	; Fread
	lea	12(sp),sp
	move.w	d0,d7	; d7: longueur du fichier
	Fclose	handle
	tst.w	d7
	bne.s	pasvide
vide	lea	msgvide,a6
	bsr	cconws_a6
abandon	Pterm0		; si le fichier est vide, on en fait rien

pasvide		
adapt	; r‚‚crit l'environnement en rempla‡ant les CR par 
	lea	env,a1	; a1: tˆte de lecture
	movea.l	a1,a2	; a2: tˆte d'‚criture
	move.w	d7,d1
	subq.w	#1,d7 	; pour le dbra sur la longueur du fichier
.boucle	move.b	(a1)+,d3
	cmpi.b	#$0d,d3	; CR: on les ignore (en ne les copiant pas)
	beq.s	.ignore
	cmpi.b	#$0a,d3	; LF 
	bne.s	.paslf
	clr.b	d3	; remplace LF par nul
.paslf	move.b	d3,(a2)+
.ignore	dbra	d7,.boucle
	clr.b	(a2)+	; ajoute 2 nulls … la fin pour ˆtre sur
	clr.b	(a2)
	suba.l	#start,a2	; a2: octets … garder
	move.l	a2,d3
	add.l	#$100,d3	; d3: taille totale … garder (inclus BASEPAGE)

	; installe l'environnement
	Supexec	#installe
			
	; garde r‚sident
	Ptermres	d3


installe	; installe le nouveau vecteur exec_os (en superviseur)
	move.l	#env,the_env.w
	move.l	exec_os.w,oldexecos
	move.l	#mon_exec_os,exec_os
	rts
	

	dc.b	'XBRA'
	dc.b	'SENV'
oldexecos	dc.l	0
mon_exec_os ; nouveau vecteur exec_os
	move.l	4(sp),a0 ; basepage
	move.l	#env,44(a0) 	; injecte la chaŒne d'environnement
	move.l	oldexecos(pc),-(sp) ; puis lance l'AES
	rts
	
env	; Les donn‚es lues du fichier aterrissent ici


****************************************************
*               PARTIE NON-RESIDENTE               *
****************************************************

	EVEN	
main	movea.l	4(sp),a5   ; BASEPAGE
	
	; on s'annonce … l'utilisateur
	lea	msg,a6
	bsr	cconws_a6

	; regarde si un fichier est donn‚ en ligne de commande
	lea	$80(a5),a5 ; a5:ligne de commande
	move.b	(a5)+,d5 	 ; d5: longueur ligne de commande
	ext.w	d5
	beq.s	loaddefaultenv
	clr.b	1(a5,d5)	 ; termine la ligne de commande
	bra.s	loadenv
	
loaddefaultenv ; charge l'environnement depuis "setenv.txt"
	lea	envtxt,a5
loadenv	; charge l'environnement depuis le fichier dont le nom est en a5
	movea.l	a5,a6
	bsr	cconws_a6	   ; affiche non du fichier, on ajoutera "charg‚" ou "pas trouv‚" plus tard	
	lea	crlf,a6
	bsr	cconws_a6
	Fopen	a5,#1	   ; ouvre fichier texte en lecture seule
	move.w	d0,handle
	bpl.s	ouvert
	; fichier pas trouv‚
	lea	notfndmsg,a6
	bsr	cconws_a6
	bra	abandon
notfndmsg	dc.b	" non trouv‚ !",$a,$d,0
ouvert	; le fichier est ouvert, lit le contenu (64Ko max, plus qu'il n'en faut)
	pea	env
	move.l	#$ffff,-(sp) ; on met tout ce qu'on peut du Fread ici et le trap en r‚sident
	move.w	d0,-(sp)
	move.w	#63,-(sp)
	bra	lit	
	; … partir de ce moment, tout ce qui est aprŠs "env" est
	; potentiellement r‚‚crit !
	
	SECTION DATA
envtxt	dc.b	"setenv.txt",0
msg	dc.b	27,"pSETENV 1.0",$a,$d,27,"q",0
