
c**************************************************************************

	SUBROUTINE ppcno10(t,ro,comp,dcomp,jac,deriv,fait,
	1 epsilon,et,ero,ex,hhe,be7e,b8e,n13e,o15e,f17e)

c routine private du module mod_nuc

c cycles PP et CNO, cf. Clayton p. 380, 392 et 430,

c �l�ments pris en compte:
c	H1, He3, He4, Li7, C12, C13, N14, N15, O16, O17, Ex
c	Ex est l'�l�ment fictif compl�ment, il n'int�resse
c	que la diffusion H2 et Be7 � l'�quilibre

c	un premier appel � rq_reac initialise et d�finit le nb.
c	d'�l�ments chimiques pour lesquels les reac. nuc. sont tabul�es
c	dans ppcno10 on ajoute Ex, soit nchim+1, puis

c Auteur: P.Morel, D�partement J.D. Cassini, O.C.A., CESAM2k

c entr�es :
c	t : temp�rature cgs
c	ro : densit� cgs
c	comp : abondances
c	deriv=.true. : on calcule le jacobien
c	fait=1 : initialisation de la composition chimique
c	    =2 : calcul de dcomp et jacobien si deriv
c	    =3 : �nergie nucl�aire et d�riv�es / t et ro
c	    =4 : production de neutrinos

c sorties
c	dcomp : d�riv�e temporelle (unit� de temps : 10**6 ans)
c	jac : jacobien (unit� de temps : 10**6 ans)
c	epsilon, et, ero, ex : �nergie thermonucl�aire (unit� de temps : s)
c			    : et d�riv�es /t, ro ,X

c Neutrinos
c	hhe, be7e, b8e, n13e, o15e, f17e : nombre de neutrinos g/s
c	hhe r�action : H1(p,e+ nu)H2
c	be7e r�action : Be7(e-,nu g)Li7
c	b8e r�action : B8(,e+ nu)Be8
c	n13e r�action : N13(,e+ nu)C13
c	o15e r�action : O15(e+,nu)N15 
c	f17e r�action : F17(,e+ nu)O17

c	ab_min : abondances n�gligeables
c	ab_ini : abondances initiales

c	r(1) : r�action H1(p,e+ nu)H2			PP
c	r(2) : r�action H2(p,g)H3
c	r(3) : r�action He3(He3,2H)He4
c	r(4) : r�action He4(He3,g)Be7
c	r(5) : r�action Li7(p,He4)He4
c	r(6) : r�action Be7(e-,nu g)Li7
c	r(7) : r�action Be7(p,g)B8(,e+ nu)Be8(,He4)He4

c	r(8) : r�action C12(p,g)N13(,e+ nu)C13		CNO
c	r(9) : r�action C13(p,g)N14
c	r(10) : r�action N14(p,g)O15(e+,nu)N15
c	r(11) : r�action N15(p,g)O16
c	r(12) : r�action N15(p,He4)C12
c	r(13) : r�action O16(p,g)F17(,e+ nu)O17
c	r(14) : r�action O17(p,He4)N14

c indices des �l�ments
c	H1 : 1
c	He3 : 2
c	He4 : 3
c	Li7 : 4
c	C12 : 5
c	C13 : 6
c	N14 : 7
c	N15 : 8
c	O16 : 9
c	O17 : 10
c	Ex  : 11

c----------------------------------------------------------------------

	USE mod_donnees, ONLY : ab_ini, ab_min, ah, amu, fmin_abon, ihe4, ili7,
	1 i_ex, langue, nchim, nom_elem, nom_xheavy,
	2 nucleo, secon6, t_inf, x0, y0, zi, z0
	USE mod_kind
	USE mod_numerique, ONLY : gauss_band
	
	IMPLICIT NONE
	
	INTEGER, INTENT(in) :: fait
	LOGICAL, INTENT(in) :: deriv
	REAL (kind=dp), INTENT(in):: t, ro
	REAL (kind=dp), INTENT(inout), DIMENSION(:) :: comp
	REAL (kind=dp), INTENT(out), DIMENSION(:,:) :: jac	
	REAL (kind=dp), INTENT(out), DIMENSION(:) :: dcomp, ex, epsilon
	REAL (kind=dp), INTENT(out) :: et, ero, hhe, be7e, b8e, n13e,
	1 o15e, f17e

	REAL (kind=dp), ALLOCATABLE, SAVE, DIMENSION(:,:) :: drx, dqx
	REAL (kind=dp), ALLOCATABLE, DIMENSION(:,:) :: a, b
	REAL (kind=dp), ALLOCATABLE, SAVE, DIMENSION(:) :: anuc, comp_dex,
	1 dmuex, dh2x, denx, dbe7x, drt, dro, r, q, dqt, dqo		
	REAL (kind=dp) :: mue, nbz, h2, dh2h, den, be7, dbe7he3, dbe7he4,
	1 dbe7mue, dbe7h, mass_ex, charge_ex, sum_a
		
	INTEGER, ALLOCATABLE, DIMENSION(:) :: indpc
	INTEGER :: i, j
	
	LOGICAL :: inversible
	
	CHARACTER (len=2) :: text
	
c--------------------------------------------------------------------------

2000	FORMAT(8es10.3)
2001	FORMAT(5es15.8)
2002	FORMAT(11es8.1)

c	initialisations

	SELECT CASE(fait)
	CASE(0)
	 
c	 d�finition de nchim: nombre d'�l�ments chimiques dont on
c	 calcule l'abondance H1, He3, He4, Li7, C13, C13, N14, N15,
c	 O16, O17, Ex

	 nchim=10+1 ; ili7=4

c	 appel d'initialisation pour tabulation des r�actions nucl�aires
c	 allocations fictives

	 ALLOCATE(drx(1,1),dqx(1,1),r(1),drt(1),dro(1),q(1),
	1 dqt(1),dqo(1),dmuex(1))
	 CALL rq_reac(comp,1.d7,1.d0,r,drt,dro,drx,q,dqt,dqo,dqx,mue,dmuex)
	 
	 DEALLOCATE(dqx,drx) ; ALLOCATE(dqx(nreac,nchim),drx(nreac,nchim))
	 	 
	CASE(1)

c d�termination des abondances initiales
c	 He3+He4=Y0
c	 Z0 = somme des �l�ments plus lourds que h�lium
c	 dans Z rapports en nombre

	 CALL abon_ini
	 
c Ex : �l�ment fictif moyenne des �l�ments # Li  et CNO

	 charge_ex=0.d0 ; mass_ex=0.d0 ; sum_a=0.d0
	 B1: DO i=4,nelem_ini		!� partir de Li=3
	  IF(elem(i) == ' C')CYCLE b1
	  IF(elem(i) == ' N')CYCLE b1
	  IF(elem(i) == ' O')CYCLE b1
	  charge_ex=charge_ex+c(i)*ab(i)	  	 
	  mass_ex=mass_ex+m(i)*ab(i)
	  sum_a=sum_a+ab(i)
	 ENDDO B1
	 charge_ex=NINT(charge_ex/sum_a) ; mass_ex=NINT(mass_ex/sum_a)
	 WRITE(text,10)NINT(mass_ex)
10	 FORMAT(i2)

c �l�ment fictif
	 nucleo(nchim)=mass_ex	!nucleo de l'�l�ment chimique reliquat
	 zi(nchim)=charge_ex	!charge de l'�l�ment chimique reliquat
	 i=NINT(charge_ex)
	 nom_elem(nchim)=elem(i)//text !nom elem. chim. rel.
	 nom_xheavy=nom_elem(nchim)
	 i_ex=nchim 	!indice de l'�l�ment chimique reliquat
 	 SELECT CASE(langue)	  
	 CASE('english')	
	  WRITE(*,1023)TRIM(nom_elem(nchim)),NINT(mass_ex),NINT(charge_ex)
	  WRITE(2,1023)TRIM(nom_elem(nchim)),NINT(mass_ex),NINT(charge_ex)	 
1023	  FORMAT(a,': fictitious species /= CNO, of mass : ',i3,/,
	1 'and charge :',i3)	 
	 CASE DEFAULT	 
	  WRITE(*,23)TRIM(nom_elem(nchim)),NINT(mass_ex),NINT(charge_ex)
	  WRITE(2,23)TRIM(nom_elem(nchim)),NINT(mass_ex),NINT(charge_ex)	 
23	  FORMAT(a,': �l�ment fictif /= CNO, de masse : ',i3,/,
	1 'et de charge :',i3)
	 END SELECT
 	 	 
c	 PRINT*,nchim ; WRITE(*,2000)nucleo(1:nchim) 
	
	 ALLOCATE(a(nchim,nchim),indpc(nchim),b(1,nchim))
	 a=0.d0 ; b=0.d0 ; indpc=1	
			
	 a(1,1)=nucleo(1)  	!H1
	 b(1,1)=x0
	
	 a(2,2)=nucleo(2)  	!He3
	 a(2,3)=nucleo(3)	!He4
	 b(1,2)=y0

	 DO j=4,nchim
	  a(3,j)=nucleo(j)	!somme j >= 5 comp(j)*nucleo(j)=Z0
	  a(4,j)=-abon_rela(6)	!somme comp(i) C, C/Z
	  a(5,j)=-abon_rela(7)	!somme comp(i) N, N/Z	 
	  a(6,j)=-abon_rela(8)	!somme comp(i) O, O/Z
	  a(11,j)=-abon_rela(3)	!somme comp(i) Li, Li/Z
	 ENDDO
		 		
	 b(1,3)=z0		!Z
	
	 a(4,5)=a(4,5)+1.d0	!C12	 		
	 a(4,6)=a(4,6)+1.d0	!C13
	
	 a(5,7)=a(5,7)+1.d0	!N14	 		
	 a(5,8)=a(5,8)+1.d0	!N15
	
	 a(6,9)=a(6,9)+1.d0	!O16	 		
	 a(6,10)=a(6,10)+1.d0	!O17
	 
	 a(11,4)=a(11,4)+1.d0	!Li7
	
c	 rapports isotopiques
	
	 a(7,2)=1.d0		!He3
	 a(7,3)=-he3she4z	!He3/He4, H2 est dans He3

	 a(8,6)=1.d0		!C13
	 a(8,5)=-c13sc12	!C13/C12
	
	 a(9,8)=1.d0		!N15
	 a(9,7)=-n15sn14	!N15/N14
	
	 a(10,10)=1.d0		!O17
	 a(10,9)=-o17so16	!O17/O16
			
c	 PRINT*,nchim
c	 DO i=1,nchim
c	  WRITE(*,2002)a(i,1:nchim),b(1,i)
c	 ENDDO

	 CALL gauss_band(a,b,indpc,nchim,nchim,nchim,1,inversible)
	 IF(.NOT.inversible)THEN
	  PRINT*,'ppcno10, matrice calcul des abondances non inversible'
	  PRINT*,'ARRET'
	  STOP
	 ENDIF	

c	 allocations diverses

	 DEALLOCATE(drt,dro,r,q,dqt,dqo,dmuex)
	 ALLOCATE(ab_ini(nchim),ab_min(nchim),drt(nreac),dro(nreac),
	1 r(nreac),q(nreac),dqt(nreac),dqo(nreac),anuc(nchim),
	2 dmuex(nchim),dh2x(nchim),denx(nchim),dbe7x(nchim))

c	 abondances initiales et abondances n�gligeables

	 comp(1:nchim)=MAX(1.d-29,b(1,1:nchim))
	 ab_ini(1:nchim)=comp(1:nchim)*nucleo(1:nchim)
	
c	 ab_min(1)=1.d-3	!H1
c	 ab_min(2)=5.d-7	!He3
c	 ab_min(3)=1.d-3	!He4
c	 ab_min(4)=1.d-14	!Li7
c	 ab_min(5)=5.d-6	!C12
c	 ab_min(6)=1.d-7	!C13
c	 ab_min(7)=1.d-6	!N14
c	 ab_min(8)=5.d-9	!N15
c	 ab_min(9)=1.d-5	!O16
c	 ab_min(10)=5.d-9	!O17
c	 ab_min(11)=1.d-6	!Ex
	 
	 ab_min=ab_ini*fmin_abon

c	 nombre/volume des m�taux dans Z
		
	 nbz=sum(comp(ihe4+1:nchim))

c abondances en DeX, H=12

	 ALLOCATE(comp_dex(nchim))
	 comp_dex=12.d0+LOG10(comp/comp(1))
	 
c �critures
 
	 SELECT CASE(langue)	  
	 CASE('english')	
	  WRITE(2,1002) ; WRITE(*,1002) 
1002	  FORMAT(/,'PP + CNO thermonuclear reactions',/)
	  WRITE(2,1003)nreac ; WRITE(*,1003)nreac 
1003	  FORMAT('number of reactions : ',i3)
	  WRITE(2,1004)nreac ; WRITE(*,1004)nchim
1004	  FORMAT('number of species : ',i3)
	  WRITE(2,1020)x0,y0,z0,z0/x0 ; WRITE(*,1020)x0,y0,z0,z0/x0
1020	  FORMAT(/,'Initial abundances/mass computed with :',/,
	1 'X0=',es10.3,', Y0=',es10.3,', Z0=',es10.3,', Z0/X0=',es10.3,/,
	2 'H1=X0, H2+He3+He4=Y0, with H2 into He3',/,
	3 'Z0 = 1-X0-Y0 = Li7+C12+C13+N14+N15+O16+O17+Ex',/)	
	  WRITE(2,1)ab_ini(1:nchim) ; WRITE(*,1)ab_ini(1:nchim)
1	  FORMAT('H1 :',es10.3,', He3 :',es10.3,', He4 :',es10.3,
	1 ', Li7 :',es10.3,/,'C12 :',es10.3,', C13 :',es10.3,
	2 ', N14 :',es10.3,', N15 :',es10.3,/,'O16 :',es10.3,
	3 ', O17 :',es10.3,', Ex :',es10.3)
	  WRITE(2,1009)comp_dex ; WRITE(*,1009)comp_dex
1009	  FORMAT(/,'Initial abundances/number: 12+Log10(Ni/Nh)',/,
	1 'H1 :',es10.3,', He3 :',es10.3,', He4 :',es10.3,', Li7 :',es10.3,
	2 /,'C12 :',es10.3,', C13 :',es10.3,', N14 :',es10.3,
	3 ', N15 :',es10.3,/,'O16 :',es10.3,', O17 :',es10.3,
	4 ', Ex :',es10.3)
	  WRITE(2,1021)comp(4)/nbz,(comp(5)+comp(6))/nbz,
	1 (comp(7)+comp(8))/nbz,(comp(9)+comp(10))/nbz,comp(11)/nbz
	  WRITE(*,1021)comp(4)/nbz,(comp(5)+comp(6))/nbz,
	1 (comp(7)+comp(8))/nbz,(comp(9)+comp(10))/nbz,comp(11)/nbz
1021	  FORMAT(/,'mass ratio by number within Z :',/,'Li/Z :',es10.3,
	1 ', C/Z :',es10.3,', N/Z :',es10.3,', O/Z :',es10.3,/,
	2 'Ex/Z :',es10.3)	
	  WRITE(2,1022)ab_ini(4)/z0,(ab_ini(5)+ab_ini(6))/z0,
	1 (ab_ini(7)+ab_ini(8))/z0,(ab_ini(9)+ab_ini(10))/z0,
	2 ab_ini(11)/z0
	  WRITE(*,1022)ab_ini(4)/z0,(ab_ini(5)+ab_ini(6))/z0,
	1 (ab_ini(7)+ab_ini(8))/z0,(ab_ini(9)+ab_ini(10))/z0,
	2 ab_ini(11)/z0	
1022	  FORMAT(/,'mass ratio by mass within Z :',/,'Li/Z :',es10.3,
	1 ', C/Z :',es10.3,', N/Z :',es10.3,', O/Z :',es10.3,/,
	2 'Ex/Z :',es10.3)	
	  WRITE(2,1014)he3she4z,c13sc12,n15sn14,o17so16
	  WRITE(*,1014)he3she4z,c13sc12,n15sn14,o17so16
1014	  FORMAT(/,'Isotopic ratios by number :',/,
	1 'He3/He4=',es10.3,', C13/C12=',es10.3,
	2 ', N15/N14=',es10.3,', O17/O16=',es10.3)	
	  WRITE(2,1005)ab_min(1:nchim) ; WRITE(*,1005)ab_min(1:nchim)
1005	  FORMAT(/,'threhold for neglectable abundances/mass :',/,
	1 'H1 :',es10.3,', He3 :',es10.3,', He4 :',es10.3,', Li7 :',es10.3,
	2 /,'C12 :',es10.3,', C13 :',es10.3,', N14 :',es10.3,
	3 ', N15 :',es10.3,/,'O16 :',es10.3,', O17:',es10.3,
	4 ', Ex:',es10.3)
	  WRITE(2,1006) ; WRITE(*,1006)
1006	  FORMAT(/,'H2, Be7 at equilibrium')
	  WRITE(2,1007) ; WRITE(*,1007)
1007	  FORMAT('Use of a table')
	  WRITE(2,1008) ; WRITE(*,1008)
1008	  FORMAT('Temporal evolution, test of precision on H1 and He4')
	 CASE DEFAULT
	  WRITE(2,2) ; WRITE(*,2) 
2	  FORMAT(/,'R�actions thermonucl�aires des cycles PP, CNO',/)
	  WRITE(2,3)nreac ; WRITE(*,3)nreac 
3	  FORMAT('nombre de r�actions : ',i3)
	  WRITE(2,4)nchim ; WRITE(*,4)nchim
4	  FORMAT('nombre d''�l�ments chimiques : ',i3)
	  WRITE(2,20)x0,y0,z0,z0/x0 ; WRITE(*,20)x0,y0,z0,z0/x0
20	  FORMAT(/,'abondances initiales/gramme d�duites de:',/,
	1 'X0=',es10.3,', Y0=',es10.3,', Z0=',es10.3,', Z0/X0=',es10.3,/,
	2 'H1=X0, H2+He3+He4=Y0, avec H2 dans He3',/,
	3 'Z0 = 1-X0-Y0 = Li7+C12+C13+N14+N15+O16+O17+Ex',/)	
	  WRITE(2,1)ab_ini(1:nchim) ; WRITE(*,1)ab_ini(1:nchim)
	  WRITE(2,9)comp_dex ; WRITE(*,9)comp_dex
9	  FORMAT(/,'Abondances initiales en nombre: 12+Log10(Ni/Nh)',/,
	1 'H1 :',es10.3,', He3 :',es10.3,', He4 :',es10.3,', Li7 :',es10.3,
	2 /,'C12 :',es10.3,', C13 :',es10.3,', N14 :',es10.3,
	3 ', N15 :',es10.3,/,'O16 :',es10.3,', O17 :',es10.3,
	4 ', Ex :',es10.3)
	  WRITE(2,21)comp(4)/nbz,(comp(5)+comp(6))/nbz,
	1 (comp(7)+comp(8))/nbz,(comp(9)+comp(10))/nbz,
	2 comp(11)/nbz
	  WRITE(*,21)comp(4)/nbz,(comp(5)+comp(6))/nbz,
	1 (comp(7)+comp(8))/nbz,(comp(9)+comp(10))/nbz,
	2 comp(11)/nbz
21	  FORMAT(/,'rapports en nombre dans Z:',/,'Li/Z :',es10.3,
	1 ', C/Z :',es10.3,', N/Z :',es10.3,', O/Z :',es10.3,/,
	2 'Ex/Z :',es10.3)	
	  WRITE(2,22)ab_ini(4)/z0,(ab_ini(5)+ab_ini(6))/z0,
	1 (ab_ini(7)+ab_ini(8))/z0,(ab_ini(9)+ab_ini(10))/z0,
	2 ab_ini(11)/z0	
	  WRITE(*,22)ab_ini(4)/z0,(ab_ini(5)+ab_ini(6))/z0,
	1 (ab_ini(7)+ab_ini(8))/z0,(ab_ini(9)+ab_ini(10))/z0,
	2 ab_ini(11)/z0
22	  FORMAT(/,'rapports en masse dans Z',/,'Li/Z :',es10.3,
	1 ', C/Z :',es10.3,', N/Z :',es10.3,', O/Z :',es10.3,/,
	2 'Ex/Z :',es10.3)	
	  WRITE(2,14)he3she4z,c13sc12,n15sn14,o17so16
	  WRITE(*,14)he3she4z,c13sc12,n15sn14,o17so16
14	  FORMAT(/,'Rapports isotopiques en nombre:',/,
	1 'He3/He4=',es10.3,', C13/C12=',es10.3,
	2 ', N15/N14=',es10.3,', O17/O16=',es10.3)	
	  WRITE(2,5)ab_min(1:nchim) ; WRITE(*,5)ab_min(1:nchim)
5	  FORMAT(/,'abondances/gramme n�gligeables:',/,
	1 'H1 :',es10.3,', He3 :',es10.3,', He4 :',es10.3,', Li7 :',es10.3,
	2 /,'C12 :',es10.3,', C13 :',es10.3,', N14 :',es10.3,
	3 ', N15 :',es10.3,/,'O16 :',es10.3,', O17 :',es10.3,
	4 ', Ex :',es10.3)
	  WRITE(2,6) ; WRITE(*,6)
6	  FORMAT(/,'H2, Be7 � l''�quilibre')
	  WRITE(2,7) ; WRITE(*,7)
7	  FORMAT(/,'on utilise une table')
	  WRITE(2,8) ; WRITE(*,8)
8	  FORMAT(/,'�vol. temporelle, test de pr�cision sur H1 et He4')
	 END SELECT
	 	
c par mole et nombre atomique
	 ab_min=ab_min/nucleo ;  anuc=ANINT(nucleo)

	 DEALLOCATE(a,b,indpc)

c r�actions
	CASE(2)
	 dcomp=0.d0 ; jac=0.d0
	
	 IF(t < t_inf)return
	
	 CALL rq_reac(comp,t,ro,r,drt,dro,drx,q,dqt,dqo,dqx,mue,dmuex)
	
c	 WRITE(*,*)'comp'
c	 WRITE(*,2000)comp(1:nchim)
c	 WRITE(*,*)'r�actions'
c	 WRITE(*,2000)r(1:nreac)

c H2
	 dh2h=r(1)/r(2) ; h2=dh2h*comp(1)

c Be7
	 den=(r(6)*mue+r(7)*comp(1)) ; be7=r(4)*comp(2)*comp(3)/den
	 dbe7he3=be7/comp(2) ; dbe7he4=be7/comp(3)
	 dbe7mue=-be7*r(6)/den ; dbe7h=-be7*r(7)/den
	
c	 WRITE(*,2000)dh2h,h2,be7,dbe7he3,dbe7he4,dbe7mue,dbe7h
c	 pause

c	 �quations d'�volution

	 dcomp(1)=-(2.d0*r(1)*comp(1)+r(2)*h2+r(5)*comp(4)
	1 +r(7)*be7+r(8)*comp(5)+r(9)*comp(6)+r(10)*comp(7)
	2 +(r(11)+r(12))*comp(8)+r(13)*comp(9)
	3 +r(14)*comp(10))*comp(1)+2.d0*r(3)*comp(2)**2		!H1
	 dcomp(2)=r(2)*comp(1)*h2-(2.d0*r(3)*comp(2)
	1 +r(4)*comp(3))*comp(2)				!He3
	 dcomp(3)=(r(3)*comp(2)-r(4)*comp(3))*comp(2)
	1 +(2.d0*(r(5)*comp(4)+r(7)*be7)+r(12)*comp(8)
	2 +r(14)*comp(10))*comp(1)				!He4
	 dcomp(4)=-r(5)*comp(1)*comp(4)+r(6)*be7*mue		!Li7
	 dcomp(5)=(-r(8)*comp(5)+r(12)*comp(8))*comp(1)		!C12
	 dcomp(6)=(r(8)*comp(5)-r(9)*comp(6))*comp(1)		!C13
	 dcomp(7)=(r(9)*comp(6)-r(10)*comp(7)+r(14)*comp(10))*comp(1) !N14
	 dcomp(8)=(r(10)*comp(7)-(r(11)+r(12))*comp(8))*comp(1)	!N15
	 dcomp(9)=(r(11)*comp(8)-r(13)*comp(9))*comp(1)		!O16
	 dcomp(10)=(r(13)*comp(9)-r(14)*comp(10))*comp(1)	!O17

c	   Pour v�rifications SUM dcomp*nucleo=0

c	 PRINT*,'ppcno10, v�rifications SUM dcomp*nucleo=0'
c	 WRITE(*,2000)DOT_PRODUCT(dcomp,anuc) ; PAUSE'v�rif'

	 dcomp(nchim)=-DOT_PRODUCT(dcomp,anuc)/anuc(nchim) !cons. des baryons

c	 calcul du jacobien
 
	 IF(deriv)THEN	!jac(i,j) : �quation, j : �l�ment i
	
c	  �quation
c	  dcomp(1)=-(2.d0*r(1)*comp(1)+r(2)*h2+r(5)*comp(4)
c	1 +r(7)*be7+r(8)*comp(5)+r(9)*comp(6)+r(10)*comp(7)
c	2 +(r(11)+r(12))*comp(8)+r(13)*comp(9)
c	3 +r(14)*comp(10))*comp(1)+2.d0*r(3)*comp(2)**2	!H1

	  jac(1,1)=-4.d0*r(1)*comp(1)-r(2)*dh2h-r(5)*comp(4)
	1 -r(7)*be7-r(8)*comp(5)-r(9)*comp(6)-r(10)*comp(7)
	2 -(r(11)+r(12))*comp(8)-r(13)*comp(9)-r(14)*comp(10)
	3 -r(7)*comp(1)*dbe7h					!d /H1
	  jac(1,2)=4.d0*r(3)*comp(2)-r(7)*comp(1)*dbe7he3	!d /He3
	  jac(1,3)=-r(7)*comp(1)*dbe7he4			!d /He3	 
	  jac(1,4)=-r(5)*comp(1)				!d /Li7
	  jac(1,5)=-r(8)*comp(1)				!d /C12
	  jac(1,6)=-r(9)*comp(1)				!d /C13
	  jac(1,7)=-r(10)*comp(1)				!d /N14
	  jac(1,8)=-(r(11)+r(12))*comp(1)			!d /N15
	  jac(1,9)=-r(13)*comp(1)				!d /O16
	  jac(1,10)=-r(14)*comp(1)				!d /O17
	 
	  DO i=1,nchim	!d�pendances dues a l'effet d'�cran et be7/muex
	   jac(1,i)=jac(1,i)
	1  -(2.d0*drx(1,i)*comp(1)+drx(2,i)*h2
	2  +drx(5,i)*comp(4)+drx(7,i)*be7
	3  +drx(8,i)*comp(5)+drx(9,i)*comp(6)
	4  +drx(10,i)*comp(7)+(drx(11,i)
	5  +drx(12,i))*comp(8)+drx(13,i)*comp(9)
	6  +drx(14,i)*comp(10)+r(7)*dbe7mue*dmuex(i))*comp(1)
	7  +2.d0*drx(3,i)*comp(2)**2
	  ENDDO
	   	 	 	 	 
c	  �quation dcomp(2)
c	  dcomp(2)=r(2)*comp(1)*h2-(2.d0*r(3)*comp(2)
c	1 +r(4)*comp(3))*comp(2)				!He3

	  jac(2,1)=r(2)*h2+r(2)*comp(1)*dh2h			!d /H1
	  jac(2,2)=-4.d0*r(3)*comp(2)-r(4)*comp(3)		!d /He3
	  jac(2,3)=-r(4)*comp(2)				!d /He4
	 
	  DO i=1,nchim		!d�pendances dues a l'effet d'�cran
	   jac(2,i)=jac(2,i)
	1  +drx(2,i)*comp(1)*h2-(2.d0*drx(3,i)*comp(2)
	2  +drx(4,i)*comp(3))*comp(2)
	  ENDDO

c	  �quation dcomp(3)
c	  dcomp(3)=(r(3)*comp(2)-r(4)*comp(3))*comp(2)
c	1 +(2.d0*(r(5)*comp(4)+r(7)*be7)+r(12)*comp(8)
c	2 +r(14)*comp(10))*comp(1)			!He4

	  jac(3,1)=2.d0*(r(5)*comp(4)+r(7)*be7+r(7)*dbe7h*comp(1))
	1 +r(12)*comp(8)+r(14)*comp(10)			!d /H1
	  jac(3,2)=2.d0*r(3)*comp(2)-r(4)*comp(3)
	1 +2.d0*r(7)*dbe7he3					!d /He3
	  jac(3,3)=-r(4)*comp(2)+2.d0*r(7)*dbe7he4		!d /He4
	  jac(3,4)=r(5)*comp(1)*2.d0				!d /Li7
	  jac(3,8)=r(12)*comp(1)				!d /N15
	  jac(3,10)=r(14)*comp(1)				!d /O17
	 
	  DO i=1,nchim		!d�pendances dues a l'effet d'�cran
	   jac(3,i)=jac(3,i)
	1  +(drx(3,i)*comp(2)-drx(4,i)*comp(3))*comp(2)
	2  +(2.d0*(drx(5,i)*comp(4)+drx(7,i)*be7)
	3  +drx(12,i)*comp(8)+2.d0*r(7)*dbe7mue*dmuex(i)
	4  +drx(14,i)*comp(10))*comp(1)
	  ENDDO
	 	 
c	  �quation dcomp(4)
c	  dcomp(4)=-r(5)*comp(1)*comp(4)+r(6)*be7*mue	!Li7

	  jac(4,1)=-r(5)*comp(4)+r(6)*dbe7h*mue		!d /H1
	  jac(4,2)=r(6)*dbe7he3*mue			!d /He3	 
	  jac(4,3)=r(6)*dbe7he4*mue			!d /He4	 
	  jac(4,4)=-r(5)*comp(1)			!d /Li7
	 
	  DO i=1,nchim		!d�pendances dues a l'effet d'�cran
	   jac(4,i)=jac(4,i)
	1  -drx(5,i)*comp(1)*comp(4)
	2  +drx(6,i)*be7*mue+r(6)*(dbe7mue*mue+be7)*dmuex(i)
	  ENDDO
	 	 	 
c	  �quation dcomp(5)	 
c	  dcomp(5)=(-r(8)*comp(5)+r(12)*comp(8))*comp(1)			!C12

	  jac(5,1)=-r(8)*comp(5)+r(12)*comp(8)	!d /H1
	  jac(5,5)=-r(8)*comp(1)				!d /C12
	  jac(5,8)=r(12)*comp(1)				!d /N15
	 
	  DO i=1,nchim		!d�pendances dues a l'effet d'�cran
	   jac(5,i)=jac(5,i)+(-drx(8,i)*comp(5)+drx(12,i)*comp(8))*comp(1)
	  ENDDO	 
	 	 
c	  �quation dcomp(6)
c	  dcomp(6)=(r(8)*comp(5)-r(9)*comp(6))*comp(1)		!C13

	  jac(6,1)=r(8)*comp(5)-r(9)*comp(6)			!d /H1
	  jac(6,5)=r(8)*comp(1)				!d /C12
	  jac(6,6)=-r(9)*comp(1)				!d /C13

	  DO i=1,nchim		!d�pendances dues a l'effet d'�cran
	   jac(6,i)=jac(6,i)
	1   +(drx(8,i)*comp(5)-drx(9,i)*comp(6))*comp(1)
	  ENDDO
	 
c	  �quation dcomp(7)	!N14	 
c	  dcomp(7)=(r(9)*comp(6)-r(10)*comp(7)+r(14)*comp(10))*comp(1)

	  jac(7,1)=r(9)*comp(6)-r(10)*comp(7)+r(14)*comp(10)	!d /H1
	  jac(7,6)=r(9)*comp(1)				!d /C13
	  jac(7,7)=-r(10)*comp(1)				!d /N14
	  jac(7,10)=r(14)*comp(1)				!d /O17

	  DO i=1,nchim		!d�pendances dues a l'effet d'�cran
	   jac(7,i)=jac(7,i)
	1  +(drx(9,i)*comp(6)-drx(10,i)*comp(7)
	2  +drx(14,i)*comp(10))*comp(1)	  
	  ENDDO
	 
c	  �quation dcomp(8)	 
c	  dcomp(8)=(r(10)*comp(7)-(r(11)+r(12))*comp(8))*comp(1)  !N15

	  jac(8,1)=r(10)*comp(7)-(r(11)+r(12))*comp(8)	!d /H1
	  jac(8,7)=r(10)*comp(1)				!d /N14
	  jac(8,8)=-(r(11)+r(12))*comp(1)			!d /N15

	  DO i=1,nchim		!d�pendances dues a l'effet d'�cran
	   jac(8,i)=jac(8,i)
	1  +(drx(10,i)*comp(7)-(drx(11,i)
	2  +drx(12,i))*comp(8))*comp(1)
	  ENDDO	  
	 
c	  �quation dcomp(9)	 
c	  dcomp(9)=(r(11)*comp(8)-r(13)*comp(9))*comp(1)	!O16

	  jac(9,1)=r(11)*comp(8)-r(13)*comp(9)		!d /H1
	  jac(9,8)=r(11)*comp(1)				!d /N15
	  jac(9,9)=-r(13)*comp(1)				!d /O16
	 
	  DO i=1,nchim		!d�pendances dues a l'effet d'�cran
	   jac(9,i)=jac(9,i)	 
	1  +(drx(11,i)*comp(8)-drx(13,i)*comp(9))*comp(1)
	  ENDDO
	 	 
c	  �quation dcomp(10)
c	  dcomp(10)=(r(13)*comp(9)-r(14)*comp(10))*comp(1)	!O17

	  jac(10,1)=r(13)*comp(9)-r(14)*comp(10)		!d /H1
	  jac(10,9)=r(13)*comp(1)				!d /O16
	  jac(10,10)=-r(14)*comp(1)				!d /O17

	  DO i=1,nchim		!d�pendances dues a l'effet d'�cran
	   jac(10,i)=jac(10,i)
	1  +(drx(13,i)*comp(9)-drx(14,i)*comp(10))*comp(1)	  
	  ENDDO		 
	 
	  DO j=1,nchim
	   DO i=1,nchim-1
	    jac(nchim,j)=jac(nchim,j)+anuc(i)*jac(i,j)
	   ENDDO
	   jac(nchim,j)=-jac(nchim,j)/anuc(nchim)
	  ENDDO

c unit�s de temps pour int�gration temporelle

	  jac=jac*secon6

	 ENDIF

	 dcomp=dcomp*secon6

c calcul de la production d'�nergie nucl�aire et d�riv�es

	CASE(3)
	 epsilon(1:4)=0.d0 ; et=0.d0 ; ero=0.d0 ; ex=0.d0
	 
	 IF(t <= t_inf)return
	
	 CALL rq_reac(comp,t,ro,r,drt,dro,drx,q,dqt,dqo,dqx,mue,dmuex)
	 
c	 mue : nombre d'electrons / mole /g = 1/poids mol. moy. par e-

c H2

	 dh2h=r(1)/r(2) ; h2=dh2h*comp(1)

c Be7

	 den=r(6)*mue+r(7)*comp(1) ; be7=r(4)*comp(2)*comp(3)/den
	 dbe7he3=be7/comp(2) ; dbe7he4=be7/comp(3)
	 IF(den /= 0.d0)THEN
	  dbe7mue=-r(6)*be7/den ; dbe7h=-r(7)*be7/den
	 ELSE
	  dbe7mue=0.d0 ; dbe7h=0.d0
	 ENDIF

	 epsilon(2)=(q(1)*comp(1)+q(2)*h2+q(7)*be7+q(5)*comp(4))*comp(1)
	1 +(q(3)*comp(2)+q(4)*comp(3))*comp(2)+q(6)*mue*be7
	 epsilon(3)=(q(8)*comp(5)+q(9)*comp(6)+q(10)*comp(7)+
	1 (q(11)+q(12))*comp(8)+q(13)*comp(9)+q(14)*comp(10))*comp(1)
	 DO i=2,4
	  epsilon(1)=epsilon(1)+epsilon(i)
	 ENDDO

	 IF(deriv)THEN	
	  et=(dqt(1)*comp(1)+dqt(2)*h2+dqt(7)*be7+dqt(5)*comp(4))*comp(1)
	1 +(dqt(3)*comp(2)+dqt(4)*comp(3))*comp(2)
	2 +dqt(6)*mue*be7+(dqt(8)*comp(5)+dqt(9)*comp(6)
	3 +dqt(10)*comp(7)+(dqt(11)+dqt(12))*comp(8)+dqt(13)*comp(9)
	4 +dqt(14)*comp(10))*comp(1)
		
	  ero=(dqo(1)*comp(1)+dqo(2)*h2+dqo(7)*be7+dqo(5)*comp(4))*comp(1)
	1 +(dqo(3)*comp(2)+dqo(4)*comp(3))*comp(2)
	2 +dqo(6)*mue*be7+(dqo(8)*comp(5)+dqo(9)*comp(6)
	3 +dqo(10)*comp(7)+(dqo(11)+dqo(12))*comp(8)+dqo(13)*comp(9)
	4 +dqo(14)*comp(10))*comp(1)
		
	  ex(1)=2.d0*q(1)*comp(1)+q(2)*dh2h+q(5)*comp(4)
	1 +q(8)*comp(5)+q(9)*comp(6)+q(10)*comp(7)
	2 +(q(11)+q(12))*comp(8)+q(13)*comp(9)+q(14)*comp(10)
	3 +q(7)*(be7+dbe7h*comp(1))+q(6)*mue*dbe7h
	  ex(2)=2.d0*q(3)*comp(2)+q(4)*comp(3)
	1 +q(7)*dbe7he3*comp(1)+q(6)*mue*dbe7he3
	  ex(3)=q(4)*comp(2)+q(7)*dbe7he4*comp(1)+q(6)*mue*dbe7he4
	  ex(4)=q(5)*comp(1)
	  ex(5)=q(8)*comp(1)
	  ex(6)=q(9)*comp(1)
	  ex(7)=q(10)*comp(1)
	  ex(8)=(q(11)+q(12))*comp(1)
	  ex(9)=q(13)*comp(1)
	  ex(10)=q(14)*comp(1)
	 
	  DO i=1,nchim	!contributions des �crans
	   ex(i)=ex(i)+(dqx(1,i)*comp(1)+dqx(2,i)*h2
	1  +dqx(7,i)*be7+dqx(5,i)*comp(4))*comp(1)
	2  +(dqx(3,i)*comp(2)+dqx(4,i)*comp(3))*comp(2)
	3  +dqx(6,i)*mue*be7+(dqx(8,i)*comp(5)
	4  +dqx(9,i)*comp(6)+dqx(10,i)*comp(7)
	5  +(dqx(11,i)+dqx(12,i))*comp(8)
	6  +dqx(13,i)*comp(9)+dqx(14,i)*comp(10))*comp(1)
	8  +(q(7)*dbe7mue*comp(1)+q(6)*(dbe7mue*mue+be7))*dmuex(i)
	  ENDDO
	 
	 ENDIF	!deriv
	   
c production de neutrinos

	CASE(4)
	 IF(t >= t_inf)THEN
	  CALL rq_reac(comp,t,ro,r,drt,dro,drx,q,dqt,dqo,dqx,mue,dmuex)
	  den=(r(6)*mue+r(7)*comp(1)) ; be7=r(4)*comp(2)*comp(3)/den	
	  hhe=r(1)*comp(1)**2/amu ; be7e=r(6)*mue*be7/amu
	  b8e=r(7)*comp(1)*be7/amu ; n13e=r(8)*comp(1)*comp(5)/amu
	  o15e=r(10)*comp(1)*comp(7)/amu
	  f17e=r(13)*comp(1)*comp(9)/amu
	 ELSE
	  hhe=0.d0 ; be7e=0.d0 ; b8e=0.d0 ; n13e=0.d0
	  o15e=0.d0 ; f17e=0.d0
	 ENDIF
	 
	CASE DEFAULT
	 PRINT*,'ppcno10, fait ne peut prendre que les valeurs 1, 2, 3 ou 4'
	 PRINT*,'ERREUR fait a la valeur:',fait
	 PRINT*,'ARRET' ; PRINT* ; STOP
	 
	END SELECT
	
	RETURN

	END SUBROUTINE ppcno10
