\documentclass[sigplan,10pt,review,anonymous]{acmart}
\settopmatter{printfolios=true,printccs=false,printacmref=false}

\acmConference[PL'18]{ACM SIGPLAN Conference on Programming Languages}{January 01--03, 2018}{New York, NY, USA}
\acmYear{2018}
\acmISBN{} % \acmISBN{978-x-xxxx-xxxx-x/YY/MM}
\acmDOI{} % \acmDOI{10.1145/nnnnnnn.nnnnnnn}
\startPage{1}

\setcopyright{none}
%\setcopyright{acmcopyright}
%\setcopyright{acmlicensed}
%\setcopyright{rightsretained}
%\copyrightyear{2018}           %% If different from \acmYear

\bibliographystyle{ACM-Reference-Format}
%% Citation style
%\citestyle{acmauthoryear}  %% For author/year citations

%include polycode.fmt

%% Some recommended packages.
\usepackage{booktabs}   %% For formal tables:
                        %% http://ctan.org/pkg/booktabs
\usepackage{subcaption} %% For complex figures with subfigures/subcaptions
                        %% http://ctan.org/pkg/subcaption


\begin{document}

%% Title information
\title{Intrinsic polymorphism in Dependent Haskell}
%% Author with single affiliation.
\author{Stephanie Weirich}
\orcid{nnnn-nnnn-nnnn-nnnn}             %% \orcid is optional
\affiliation{
  \position{Professor}
  \department{Computer and Information Science}              %% \department is recommended
  \institution{University of Pennsylvania}            %% \institution is required
  \streetaddress{Street1 Address1}
  \city{City1}
  \state{State1}
  \postcode{Post-Code1}
  \country{Country1}                    %% \country is recommended
}
\email{sweirichcis.upenn.edu}          %% \email is recommended

\begin{abstract}
Text of abstract \ldots.
\end{abstract}


\begin{CCSXML}
<ccs2012>
<concept>
<concept_id>10011007.10011006.10011008</concept_id>
<concept_desc>Software and its engineering~General programming languages</concept_desc>
<concept_significance>500</concept_significance>
</concept>
<concept>
<concept_id>10003456.10003457.10003521.10003525</concept_id>
<concept_desc>Social and professional topics~History of programming languages</concept_desc>
<concept_significance>300</concept_significance>
</concept>
</ccs2012>
\end{CCSXML}

\ccsdesc[500]{Software and its engineering~General programming languages}
\ccsdesc[300]{Social and professional topics~History of programming languages}
%% End of generated code


%% Keywords
%% comma separated list
\keywords{keyword1, keyword2, keyword3}  %% \keywords are mandatory in final camera-ready submission


%% \maketitle
%% Note: \maketitle command must come after title commands, author
%% commands, abstract environment, Computing Classification System
%% environment and commands, and keywords command.
\maketitle

\section{Introduction}

%if False
\begin{code}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE EmptyCase #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

{-# LANGUAGE AllowAmbiguousTypes #-}

{-# OPTIONS_GHC -fwarn-incomplete-patterns -Wno-redundant-constraints #-}
module SysF where

import Prelude hiding ((!!))
import Test.QuickCheck
import Data.Singletons
import Data.Singletons.Prelude
import Data.Singletons.TH
import Data.Kind(Type)

import Data.Type.Equality

import Unsafe.Coerce
\end{code}
%endif

We will use deBruijn indices, with parallel substitutions to
represent type variables in System F. 

Why are we doing this:
\begin{enumerate}
  \item Demonstrate what is possible for intrinsic type representations
    in Haskell now.
  \item Compare capabilties with Coq and Agda
  \item Polymorphism is particularly tricky and not well represented in
    Haskell literature
\end{enumerate}

Comparison: better than Coq/Agda
\begin{enumerate}
  \item No termination proof required. Significantly simpler definition
    of substitution
  \item "Extensional"-like treatment of equality. (Does this show up
    anywhere???)
\end{enumerate}

Comparison: worse than Coq/Agda
\begin{enumerate}
  \item No proofs! Have to use unsafeCoerce. Confidence through testing
    (or proofs on paper/another system).
  \item No native type-level lambdas. Had to be clever and "defunctionalize"
    the representation of substitution.
  \item Ecosystem not designed for TypeInType (i.e. singletons!). So,
    cunningly selected version that did not index kinds, only indexed types.
\end{enumerate}


Discussion: Should we make the type indices more strongly typed?

Yes: earlier bug finding, tighter interface

No: it's all statically checked anyways, less support from singletons
    needs TypeInType, more proofs required


\subsection{Preliminaries}

First, a datatype for indices themselves --- natural numbers.
For simplicity, we will display natural numbers as Ints.
Eventually, we will move this code into another file as it is
fairly boring. Would be good to have a run-time representation
with "Int" (like PeanoRepr).

%if False
\begin{code}
$(singletons [d|
    data Nat = Z | S Nat deriving (Eq, Ord)

    addNat :: Nat -> Nat -> Nat
    addNat Z     x = x
    addNat (S y) x  = S (addNat y x)

    mulNat :: Nat -> Nat -> Nat
    mulNat Z     x = Z
    mulNat (S y) x = addNat x (mulNat y x)

    subNat :: Nat -> Nat -> Nat
    subNat x     Z = x
    subNat (S x) (S y) = subNat x y

    applyN :: Nat -> (a -> a) -> a -> a
    applyN Z     f x = x
    applyN (S n) f x = f (applyN n f x)

    natLength :: [a] -> Nat
    natLength [] = Z
    natLength (_:xs) = S (natLength xs)

    -- safe indexing operation
    natIdx :: [a] -> Nat -> Maybe a
    natIdx (x:_)  Z     = Just x
    natIdx (_:xs)(S n)  = natIdx xs n
    natIdx []    n      = Nothing
 
    |])

instance Num Nat where
  fromInteger 0 = Z
  fromInteger n | n < 0 = error "CANNOT represent negative numbers"
  fromInteger n = S (fromInteger (n - 1))

  (+) = addNat
  (*) = mulNat
  (-) = subNat

  negate x = error "Negative number"
  abs x    = x
  signum Z = 0
  signum x = 1

instance Enum Nat where
  toEnum :: Int -> Nat
  toEnum = fromInteger . toInteger
  fromEnum :: Nat -> Int
  fromEnum = natToInt

natToInt :: Nat -> Int
natToInt Z = 0
natToInt (S m) = 1 + natToInt m

instance Show Nat where
  show = show . natToInt

class Index a where
  type Element a
  (!!) :: a -> Nat -> Element a

instance Index [a] where
  type Element [a] = a
  (x:_)   !!  Z     = x
  (_:xs)  !! (S n)  = xs !! n
  []      !! n      = error "(!!): too few elements in index"

  
\end{code}
%endif

\section{Type representation}

First, our datatype for types. Type variables are represented by indices (natural numbers). 

\begin{code}
$(singletons [d|
    data Ty =
         BaseTy
      |  VarTy Nat
      |  FnTy Ty Ty
      |  PolyTy Nat Ty        -- forall {a,b}. a -> b
                              -- PolyTy 2 (FnTy (VarTy 0) (VarTy 1))
         deriving (Eq,Show)
    |])
\end{code}

Now, the representation of substitutions. In this representation,
substitutions are usually defined as functions from (natural number) indices
to types. This makes sense, in general, because these substitutions are
"infinite" --- they apply to all type indices.

However, in Haskell, we want to work with these substitutions at the type
level, which does not include type-level lambda expressions. SVarfore, it is
difficult to define the appropriate substitutions.

Therefore, we use the following datatype as a "defunctionalized" version of
substitions and substitution-producing operations. For convenience, this is
not a minimal definition; we can define some of these operations in terms of
others. However, it is more convenient to have them all defined in this way.

We could have also let the singletons library take care of the
defunctionalization for us. But that might be even more difficult to work
with.

\begin{code}
$(singletons [d|
    data Sub =
        IdSub 
     |  ConsSub Ty Sub
     |  LiftSub Nat Sub
     |  TailSub Nat Sub
     |  IncSub Nat     
        deriving (Eq, Show)
    |])
\end{code}

We can understand these substitutions by looking at their behavior on
type variables (the function |applys| below).

\begin{itemize}
\item |IdSub| - the identity substitution. When used during substitution,
    maps all type variables to themselves.
\item |ConsSub ty s| - extends a substitution, by adding a new definition for
    index 0 and shifting everything in |s| one step to the right.
\item |LiftSub k s| - exactly what we need when we go under a binder.
    indices 0..k-1 are left alone, and the free variables in the range of s
    are all incremented by k.
\item |TailSub k s| - the opposite of cons. shift everything in |s| |k| steps
    to the left, dropping the first |k| elements.
\item |IncSub k| - increment all variables by |k|.
\end{itemize}

Because we are working with n-ary binders, some of these operations are
n-ary.

The `subst` operation then extends the substitution for a single index
throughout the type structure. When this function calls itself recursively
under a binder, it uses `LiftSub` to modify the input substitution
appropriately.


\begin{code}
$(singletons [d|
    inc :: Nat -> Ty -> Ty
    inc k = subst (IncSub k)

    -- determine s !! i
    applys :: Sub -> Nat -> Ty
    applys IdSub          x  = VarTy x
    applys (ConsSub e s)  x  = case x of
                                 Z      -> e
                                 (S m)  -> applys s m
    applys (LiftSub k s)  x  = if x < k 
                                 then VarTy x
                                 else inc k (applys s (subNat x k))
    applys (TailSub k s)  x  = applys s (addNat k x)
    applys (IncSub  k)    x  = VarTy (addNat k x)

    -- type substitution operation           
    subst :: Sub -> Ty -> Ty
    subst s BaseTy        = BaseTy
    subst s (VarTy k)     = applys s k
    subst s (FnTy a r)    = FnTy (subst s a) (subst s r)
    subst s (PolyTy k a)  = PolyTy k (subst (LiftSub k s) a) 
    |])

instance Index Sub where
  type Element Sub = Ty
  s !! x = applys s x
\end{code}

We can also visualize substiutions as infinite lists of types,
where the ith type in the list is the substitution for variable i.

\begin{code}
toList :: Sub -> [Ty]
toList IdSub           = VarTy <$> [0, 1 ..]
toList (ConsSub x y)   = (x : toList y)
toList (IncSub k)      = VarTy <$> enumFrom k
toList (TailSub k s)   = applyN k tail (toList s)
toList (LiftSub k s)   = if k > 0
  then (VarTy <$> [0 .. k-1]) <> (map (inc k) (toList s))
  else toList s
\end{code}

We can express the connection between the two interpretations of substitutions
using the following quickCheck property.  In otherwords, at any index n,
the result of applys is the same as first converting the substitution to a list
and then accessing the nth element.

\begin{code}
prop_applys_toList :: Sub -> Nat -> Bool
prop_applys_toList s n =
  s !! n == toList s !! n
\end{code}

More generally, we can test properties about the various substitution
operations (as this is not a minimal set).

\begin{code}
prop_IdSub_def n =
  IdSub !! n == (ConsSub (VarTy 0) (IncSub 1)) !! n

prop_IncSub_def k n =
  IncSub k !! n == TailSub k IdSub !! n
\end{code}




\section{Terms and types}

Now, in this section, use the promoted, quantified types to develop an
intrinsically-typed version of System F.

Before we do so, we need two additional operations on substitutions.

First, we need a way to interpret a list of types as a substitution,
where the first element of the list is the substition for TyVar 0,
etc. We do so, with the following unremarkable function.

\begin{code}
$(singletons [d|
  fromList :: [Ty] -> Sub
  fromList []        = IdSub
  fromList (ty:tys)  = ConsSub ty (fromList tys)
  |])
\end{code}

\begin{code}
prop_toList_fromList tys =
  take (length tys) (toList (fromList tys)) == tys
\end{code}

Second, we give a name to the operation of mapping the increment operation
across a list of types.

\begin{code}
$(singletons [d|
    incList :: Nat -> [Ty] -> [Ty]
    incList k tys = map (subst (IncSub k)) tys
   |])
\end{code}

With these two operations, we can define the GADTs for terms, indexed by a
context (i.e. list of types for the free variables of the term) and the type
of the term.

The `Sing a` type, defined in the singletons library, indicates the use of
dependent types. These are arguments that are used both as data (so must be
args to the data constructors) but also must appear later in the type. For 


In this term, the `TyLam` operation has to increment all of the type variables
in the context `g` by `k`, the number of type binders.  In the `TyApp` case,
we need to know that the number of binders in the polymorphic function matches
the number of type arguments. We then turn the type arguments into a
substitution which we use to calculate the result type.

\begin{code}

data Var :: [Ty] -> Ty -> Type where
  VZ  :: Var (ty:g) ty
  VS  :: Var g ty -> Var (ty1:g) ty

data Exp :: [Ty] -> Ty -> Type where
  
  EBase  :: Exp g BaseTy
  
  EVar   :: Var g ty
         -> Exp g ty
         
  ELam   :: Sing ty1
         -> Exp (ty1:g) ty2
         -> Exp g (FnTy ty1 ty2)
         
  EApp   :: Exp g (FnTy ty1 ty2)
         -> Exp g ty1
         -> Exp g ty2
  
  TyLam  :: Sing k
         -> Exp (IncList k g) ty
         -> Exp g (PolyTy k ty)
         
  TyApp  :: (k ~ NatLength tys)
         => Exp g (PolyTy k ty)
         -> Sing tys
         -> Exp g (Subst (FromList tys) ty)
         
\end{code}

For example, we can type check the polymorphic identity function:

\begin{code}
$(singletons [d|
     sid :: Ty
     sid = (PolyTy (S Z) (FnTy (VarTy Z) (VarTy Z)))
 |])

pid :: Exp '[] Sid
pid = TyLam (SS SZ) (ELam (SVarTy SZ) (EVar VZ))

pidpid :: Exp '[] Sid
pidpid = EApp (TyApp pid (SCons sSid SNil)) pid
\end{code}


\subsection{Substituting terms in types}

The next step is to define the operation of type substitution in terms.

Again, we name some operations that we would like to use with type contexts.


\begin{code}
$(singletons [d|  
    liftList :: Nat -> Sub -> [Ty] -> [Ty]
    liftList k s = map (subst (LiftSub k s)) 
               
    substList :: Sub -> [Ty] -> [Ty]
    substList s = map (subst s)                                
   |])
\end{code}


In this definition, instead of using the simply-typed version of these operations,
we need to use some Singletons to capture the dependency. For example, the operation

\begin{spec}
sSubst :: Sing s -> Sing ty -> Sing (Subst s ty)
\end{spec}

is the dependent version of `subst` above. i.e. the process of applying a substitution
to a type. We need to use this operation in the lambda case, because we need to substitute
in the type annotations.

\begin{code}
-- Substitute types in terms
substTy :: forall s g ty. Sing s -> (Exp g ty) -> Exp (SubstList s g) (Subst s ty)
substTy s EBase         = EBase
substTy s (EVar v)      = EVar (substVar @s v)
substTy s (ELam ty e)   = ELam (sSubst s ty) (substTy s e)
substTy s (EApp e1 e2)  = EApp (substTy s e1) (substTy s e2)
substTy s (TyLam k e)
  | Refl <- axiom_LiftIncList1 @g s k
  = TyLam k (substTy (SLiftSub k s) e)
  
substTy s (TyApp (e :: Exp g (PolyTy k ty1)) tys)
  | Refl <- typeEquality2 @ty1 s tys
  , Refl <- typeEquality3 @(SubstSym1 s) tys
  = TyApp (substTy s e) (sSubstList s tys)
\end{code}


In the first case of the function, we need to show that substituting through
variable lookups is type-sound.

\begin{code}
substVar :: forall s g ty. Var g ty -> Var (SubstList s g) (Subst s ty)
substVar VZ      = VZ
substVar (VS v)  = VS (substVar @s v)
\end{code}

Note that this function is more proof than code --- if you look at it, it is
just an identity function.  It is justified to replace the above with the
definition below, which has equivalent behavior.

\begin{spec}
substVar :: (Var g ty) -> Var (SubstList s g) (Subst s ty)
substVar v = unsafeCoerce v
\end{spec}

This is any example where, if we are not willing to use unsafeCoerce, we need
to pay a performance cost for the use of an intrinsic representation. The
intrinsic representation uses terms \emph{as proofs}.

This is not an issue with the fact that we are working in Haskell. Even in Coq
or Agda, we would face this dilemma. Indeed, there doesn't seem to be a way
out of this quandry without stepping out of the proof system.

Only Cedille's zero-cost conversions would be able to attack this issue. 
In that vein, perhaps Haskell could similarly support a way to derive the
fact that even though two terms have different types, they have the same runtime
representation. 

\begin{spec}
instance Coercible (Var g ty) (Var (SubstList s g) (Subst s ty)) where
  ...
substVar :: Sing s -> (Var g ty) -> Var (SubstList s g) (Subst s ty)
substVar s v = coerce v
\end{spec}

The last two branches of substTy requires more traditional proofs about type
equality.  (A version in Coq or Agda would also need to rely on these proofs.)

In the type abstraction case, we call the function recursively after shifting
the substitution by the number of binders in the abstraction.

we have

\begin{spec}
   substTy (SLiftSub k s) e ::
       Exp (SubstList (LiftSub k s) g) (Subst (LiftSub k s) ty)
\end{spec}

we want to produce a term of type

\begin{spec}
   Exp s (Subst s g) (Subst s (PolyTy k ty))
   ==
   Exp s (Subst s g) (PolyTy k (Subst (LiftSub k s) ty))
\end{spec}

we can do so with the TyLam, given a body of type

\begin{spec}
   Exp s (IncList k (Subst s g)) (Subst (LiftSub k s) ty)
\end{spec}

so the type of the body lines up. But we need a type equality between the
contexts.

\begin{code}
axiom_LiftInc :: forall g s k.
  Sing s -> Sing k -> Subst (LiftSub k s) (Subst (IncSub k) g) :~: (Subst (IncSub k) (Subst s g))
axiom_LiftInc _ _ = unsafeCoerce Refl

axiom_LiftIncList1 :: forall g s k.
  Sing s -> Sing k -> (LiftList k s (IncList k g)) :~: (IncList k (SubstList s g))
axiom_LiftIncList1 _ _ = unsafeCoerce Refl
\end{code}

Why is this equality justfied? Consider what happens in the case of some type variable
k1, that occurs in one type in the list. In this case, we need to show that 

  Subst (LiftSub k s) (Subst (IncSub k) (VarTy k1))  :~: Subst (IncSub k) (Subst s (VarTy k1))

So we have the following sequence of equalities connecting the left-hand-side with the
right-hand side.

\begin{spec}
   LHS  == Subst (LiftSub k s) (VarTy (AddNat k k1))
         {{ unfolding definitions }}
        == if (AddNat k k1) < k 
             then VarTy (AddNat k k1)
             else inc k s !! (subNat (AddNat k k1) k)
         {{ first case is impossible }}
        == inc k s !! (subNat (AddNat k k1) k)
         {{ arithmetic }}
        == inc k (s !! k1)
         {{ unfolding definitions }}
        == RHS
\end{spec}

We don't want to prove this equation in Haskell. That would impose a runtime
cost to our substitution function. Instead, we would like to declare this
property as an "axiom", one that we believe holds about the system.

We can gain confidence in the axiom in two ways. On one hand, we could try to
prove it on paper, or in an external tool, or in LiquidHaskell. However, it is
simpler to test it via quickCheck.  So, let's state it as a quickcheck
property.

\begin{code}
prop_LiftIncList1 :: [Ty] -> Sub -> Nat -> Bool
prop_LiftIncList1 g s k = liftList k s (incList k g) == incList k (substList s g)
\end{code}



\begin{code}
typeEquality2 :: forall ty1 s tys.
  Sing s -> Sing tys ->
  Subst (FromList (SubstList s tys))
    (Subst (LiftSub (NatLength tys) s) ty1)
     :~: 
  Subst s (Subst (FromList tys) ty1)
typeEquality2 _ _ = unsafeCoerce Refl

prop2 :: Ty -> Sub -> [Ty] -> Bool
prop2 ty1 s tys =
  subst (fromList (substList s tys))
    (subst (LiftSub (natLength tys) s) ty1)
    ==
  subst s (subst (fromList tys) ty1)


typeEquality3 :: forall f tys.
  Sing tys ->
  NatLength (Map f tys) :~: NatLength tys
typeEquality3 _ = unsafeCoerce Refl

prop3 :: (a -> b) -> [a] -> Bool
prop3 f tys = natLength (map f tys) == natLength tys

\end{code}


\subsection{Term substitutions}

i.e. all this substitution stuff *again*, but more intrinsically typed. 


\begin{code}
data ESub g g' where
  EIdSub   :: ESub g g
  EConsSub :: Exp g' ty -> ESub g g' -> ESub (ty:g) g'
  ETailSub :: ESub (ty:g) g' -> ESub g g'
  EIncSub  :: ESub g (ty:g)
  ELiftSub :: ESub g g' -> ESub (ty:g) (ty:g')

----------------
applyESub :: ESub g g' -> Var g ty -> Exp g' ty
applyESub EIdSub         v = EVar v
applyESub (EConsSub e s) v = case v of
                                VZ -> e
                                VS m -> applyESub s m
applyESub (ETailSub s)   v = applyESub s (VS v)
applyESub EIncSub        v = EVar (VS v)
applyESub (ELiftSub s)   v = case v of
                                VZ -> EVar VZ
                                VS m -> substE EIncSub (applyESub s m)

---------------------

-- Composition of type-increment and term substitution.
-- Kinda nice that we have a concrete definition of term substitutions
-- to work from.
incESub :: Sing k -> ESub g g' -> ESub (IncList k g) (IncList k g')
incESub k EIdSub         = EIdSub
incESub k (EConsSub e s) = EConsSub (substTy (SIncSub k) e) (incESub k s)
incESub k (ETailSub s)   = ETailSub (incESub k s)
incESub k EIncSub        = EIncSub
incESub k (ELiftSub s)   = ELiftSub (incESub k s)

---------------------

substE :: ESub g g' -> Exp g ty -> Exp g' ty
substE s EBase         = EBase
substE s (EVar v)      = applyESub s v
substE s (EApp e1 e2)  = EApp (substE s e1) (substE s e2)
substE s (ELam ty e)   = ELam ty (substE (ELiftSub s) e)
substE s (TyLam k e)   = TyLam k (substE (incESub k s) e)
substE s (TyApp e tys) = TyApp (substE s e) tys


\end{code}
Example of an operation defined over this representation --- evaluation.

\begin{code}
data Val ty where
  VBase  :: Val BaseTy
  VLam   :: Sing t1 -> Exp '[t1] t2
         -> Val (FnTy t1 t2)
  VTyLam :: Sing k -> Exp '[] t2
         -> Val (PolyTy k t2)

-- Closed expressions evaluate to values (or diverge)
eval :: Exp '[] ty -> Val ty
eval EBase = VBase
eval (ELam t1 e1) = VLam t1 e1
eval (EApp e1 e2) = case eval e1 of
   VLam _ e1' -> eval (substE (EConsSub e2 EIdSub) e1')
eval (TyLam k e1) = VTyLam k e1
eval (TyApp e tys) = case eval e of
   VTyLam k e' -> eval (substTy (sFromList tys) e')
eval (EVar v) = case v of {}
\end{code}


Another example -- parallel reduction. Needs an axiom!

\begin{code}
axiomPar :: forall g k ty1 tys. (k ~ NatLength tys) => Sing tys ->
     SubstList (FromList tys) (IncList k g) :~: g
axiomPar _ = undefined

prop_Par g ty1 tys = substList (fromList tys) (incList (natLength tys) g) == g

par :: forall g ty. Exp g ty -> Exp g ty
par EBase    = EBase
par (EVar v) = EVar v
par (EApp e1 e2) = case par e1 of
  ELam _ty e1' -> substE (EConsSub e2 EIdSub) e1'
  e1'         -> EApp e1' e2
par (ELam ty e) = ELam ty (par e)
par (TyApp (e :: Exp g (PolyTy k ty1)) (tys :: Sing tys)) = case par e of
  TyLam k (e' :: Exp (IncList k g) ty1)
    | Refl <- axiomPar @g @k @ty1 tys
    -> e1 where
      e1 :: Exp (SubstList (FromList tys) (IncList k g)) (Subst (FromList tys) ty1)
      e1 = substTy (sFromList tys) e'
  e1' -> TyApp e1' tys
par (TyLam k e) = TyLam k e
\end{code}

Example -- a System F type checker

\begin{code}
data UExp =
    UVar Nat
  | ULam Ty UExp
  | UApp UExp UExp
  | UTyLam Nat UExp
  | UTyApp UExp [Ty]
\end{code}

Untyped version
\begin{code}
utc :: Nat -> [Ty] -> UExp -> Maybe Ty
utc k g (UVar j)    = natIdx g j
utc k g (ULam t1 e) = do
  t2 <- utc k (t1:g) e
  return (FnTy t1 t2)
utc k g (UApp e1 e2) = do
  t1 <- utc k g e1
  t2 <- utc k g e2
  case t1 of
    FnTy t12 t22
      | t12 == t2 -> Just t22
    _ -> Nothing
utc k g (UTyLam j e) = do
  ty <- utc (k+j) g e
  return (PolyTy k ty)
utc k g (UTyApp e tys) = do
  ty <- utc k g e
  case ty of
    PolyTy k ty1
      | k == natLength tys
      -> Just (subst (fromList tys) ty1)
    _ -> Nothing
\end{code}

Typed version, in CPS style

We use CPS style becaus we need to return both the intriniscally typed term and a singleton for its type.
Otherwise we need to define a special purpose datatype. But maybe that is easier to understand anyways.

\begin{code}
data TcResult f ctx where
  Checks :: Sing t -> f ctx t -> TcResult f ctx
  Errors :: String -> TcResult f ctx


tcVar :: Sing ctx -> Nat -> TcResult Var ctx
tcVar (SCons t _ )   Z     = Checks t VZ
tcVar (SCons _ ts)  (S m)  =
  case tcVar ts m of
   Checks t v -> Checks t (VS v)
   Errors s   -> Errors s
tcVar SNil          _     = Errors "unbound variable"
   
tcExp :: Sing ctx -> UExp -> TcResult Exp ctx
tcExp g (UVar k) =
  case tcVar g k of
    Checks t v -> Checks t (EVar v)
    Errors s   -> Errors s 
tcExp g (ULam t1 u) =
  case (toSing t1) of
    SomeSing sT1 ->
      case (tcExp (SCons sT1 g) u) of
        Checks sT2 e -> Checks (SFnTy sT1 sT2) (ELam sT1 e)
        Errors s     -> Errors s
tcExp g (UApp u1 u2) =
  case (tcExp g u1) of
    Checks t1 e1 -> case (tcExp g u2) of
      Checks t2 e2 ->
        case t1 of
          SFnTy t11 t12 ->
            case testEquality t11 t2 of
              Just Refl -> Checks t12 (EApp e1 e2)
              Nothing -> Errors "Types don't match"
          _ -> Errors "Not a function type"
      Errors s -> Errors s
    Errors s -> Errors s
tcExp g (UTyLam k u1) =
  case (toSing k) of
    SomeSing sK ->
      case (tcExp (sIncList sK g) u1) of
        Checks t1 e1 -> Checks (SPolyTy sK t1) (TyLam sK e1)
        Errors s     -> Errors s
tcExp g (UTyApp u1 tys) =
  case (toSing tys) of
    SomeSing sTys ->
      case (tcExp g u1) of
        Checks t e1 ->
          case t of
            (SPolyTy sK t1) ->
              case testEquality sK (sNatLength sTys) of
                Just Refl -> Checks (sSubst (sFromList sTys) t1) (TyApp e1 sTys)
                Nothing -> Errors "Wrong number of type args"
            _ -> Errors "Wrong type in tyapp"
        Errors s -> Errors s
\end{code}



\section {testing code}

\begin{code}
fi :: Integer -> Nat
fi n = if n == 0 then Z
    else if n < 0 then fi (-n)
    else S (fi (n - 1))

upto :: Nat -> [Nat]
upto Z = []
upto (S m) = m : upto m
  
instance Arbitrary Nat where
  arbitrary = fi <$> arbitrary
  shrink Z = []
  shrink (S n) = [n]


instance Arbitrary Ty where
  arbitrary = sized (gt Z) where
    base n = oneof (return BaseTy : [return (VarTy k) | k <- upto (fi 5) ])
    gl :: Nat -> Int -> Gen [Ty]
    gl n m = (gt n m) >>= \ty -> return [ty]
    
    gt :: Nat -> Int -> Gen Ty
    gt n m =
      if m <= 1 then base n
      else
      let m' = m `div` 2 in
      frequency
      [(2, base n),
       (1, FnTy <$> gt n m' <*> gt n m'),
       (1, do
           k <- elements [Z, S Z, S (S Z), S (S (S Z))]
           a <- gl (n + k) m'
           r <- gt (n + k) m'
           return (PolyTy k r))]

instance Arbitrary Sub where
  arbitrary = sized gt where
    base = oneof [return IdSub, IncSub <$> arbitrary]
    gt m =
      if m <= 1 then base else
      let m' = m `div` 2 in
      frequency
      [(1, base),
       (1, ConsSub <$> arbitrary <*> gt m'), -- always closed? FVs?
       (1, LiftSub <$> arbitrary <*> gt m'),
       (1, TailSub <$> arbitrary <*> gt m')]

    


----------------------------------------------------------------------
----------------------------------------------------------------------


prop_rename_inc_tail k c s =
   subst (TailSub k s) c == subst s (subst (IncSub k) c)

prop_cons_sub ty ss tt =
  subst (ConsSub ty ss) (subst (IncSub 1) tt) == subst ss tt

\end{code}


\begin{code}
qc :: Testable prop => prop -> IO ()
qc = quickCheckWith (stdArgs { maxSuccess = 1000 })
\end{code}



%% Acknowledgments
\begin{acks}                            %% acks environment is optional
                                        %% contents suppressed with 'anonymous'
  %% Commands \grantsponsor{<sponsorID>}{<name>}{<url>} and
  %% \grantnum[<url>]{<sponsorID>}{<number>} should be used to
  %% acknowledge financial support and will be used by metadata
  %% extraction tools.
  This material is based upon work supported by the
  \grantsponsor{GS100000001}{National Science
    Foundation}{http://dx.doi.org/10.13039/100000001} under Grant
  No.~\grantnum{GS100000001}{nnnnnnn} and Grant
  No.~\grantnum{GS100000001}{mmmmmmm}.  Any opinions, findings, and
  conclusions or recommendations expressed in this material are those
  of the author and do not necessarily reflect the views of the
  National Science Foundation.
\end{acks}


%% Bibliography
%\bibliography{bibfile}


%% Appendix
\appendix
\section{Appendix}

Text of appendix \ldots

\end{document}
