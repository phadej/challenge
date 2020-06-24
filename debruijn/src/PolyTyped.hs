module PolyTyped where

import Imports

-- We use Subst for type-level indices and substitutions and SubstTyped for
-- expression-level indices and substitution. To be clear which is which, we
-- qualify the imports (W for weak, S for strong).
import qualified Subst as W
import qualified SubstTyped as S

import SubstProperties 

-- We import the definition of System F types from the weakly-typed version of
-- the AST. This will allow us to write a type checker that shares these
-- types. (See TypeCheck.hs).

import Poly (Ty(..), STy(..))


-- NOTE: generated by singleton brackets in Poly

exTy :: Sing (IntTy :-> IntTy)
exTy = SIntTy :%-> SIntTy


-- | The well-typed AST for System F
data Exp :: [Ty] -> Ty -> Type where

  IntE   :: Int
         -> Exp g IntTy

  VarE   :: S.Idx g t
         -> Exp g t

  LamE   :: Π (t1 :: Ty)          -- type of binder
         -> Exp (t1:g) t2         -- body of abstraction
         -> Exp g (t1 :-> t2)

  AppE   :: Exp g (t1 :-> t2)     -- function
         -> Exp g t1              -- argument
         -> Exp g t2

  TyLam  :: Exp (IncList g) t     -- bind a type variable
         -> Exp g (PolyTy t)

  TyApp  :: Exp g (PolyTy t1)     -- type function
         -> Π (t2 :: Ty)          -- type argument
         -> Exp g (W.Subst (W.SingleSub t2) t1)

-- Example, the polymorphic identity function
polyId :: Exp '[] (PolyTy (VarTy W.Z :-> VarTy W.Z))
polyId = TyLam (LamE (SVarTy W.SZ) (VarE S.Z))

-- Example, an instance of the polymorphic identity function
intId :: Exp '[] (IntTy :-> IntTy)
intId = TyApp polyId SIntTy


-- Example, an instance of the polymorphic identity function
alphaId :: Exp '[] (VarTy W.Z :-> VarTy W.Z)
alphaId = TyApp polyId (SVarTy W.SZ)




-- Although the types are *much* more explicit, the actual code of the
-- instance definition is unchanged from [Poly.hs](Poly.hs)
instance S.SubstDB Exp where

   var :: S.Idx g t -> Exp g t
   var = VarE

   subst :: S.Sub Exp g g' -> Exp g t -> Exp g' t
   subst s (IntE x)     = IntE x
   subst s (VarE x)     = S.applySub s x
   subst s (LamE ty e)  = LamE ty (S.subst (S.lift s) e)
   subst s (AppE e1 e2) = AppE (S.subst s e1) (S.subst s e2)
   subst s (TyLam e)    = TyLam (S.subst (incTy s) e)
   subst s (TyApp e t)  = TyApp (S.subst s e) t

-- | Apply a type substitution to an expression
substTy :: forall g s ty.
   Π (s :: W.Sub Ty) -> Exp g ty -> Exp (Map (W.SubstSym1 s) g) (W.Subst s ty)
substTy s (IntE x)     = IntE x
substTy s (VarE n)     = VarE $ S.mapIdx @(W.SubstSym1 s)  n
substTy s (LamE t e)   = LamE (W.sSubst s t)   (substTy s e)
substTy s (AppE e1 e2) = AppE (substTy s e1) (substTy s e2)
substTy s (TyLam (e :: Exp (IncList g) t))    
    | Refl <- axiom1 @g s 
     = TyLam (substTy (W.sLift s) e)
substTy s (TyApp (e :: Exp g (PolyTy t1)) (t :: STy t2))  
    | Refl <- axiom2 @t1 @t2 s
     = TyApp (substTy s e) (W.sSubst s t)

-- | Increment all types in a term substitution
-- Need to know that IncList ~ Map (SubstSym1 IncSub)
incTy :: forall g g'. S.Sub Exp g g'
      -> S.Sub Exp (IncList g) (IncList g')
incTy (S.Inc (x :: S.IncBy g1)) 
  | Refl <- axiom_map1 @(W.SubstSym1 W.IncSub) @g1 @g
  = S.Inc (S.mapInc @(W.SubstSym1 W.IncSub)  x) 
incTy (e S.:< s1)   = substTy W.sIncSub e S.:< incTy s1
incTy (s1 S.:<> s2) = incTy s1 S.:<> incTy s2


-------------------------------------------------------------------

-- | Small-step evaluation of closed terms
step :: Exp '[] t -> Maybe (Exp '[] t)
step (IntE x)     = Nothing
step (VarE n)     = case n of {}  
step (LamE t e)   = Nothing
step (AppE e1 e2) = Just $ stepApp e1 e2
step (TyLam e)    = Nothing
step (TyApp e t)  = Just $ stepTyApp e t

-- | Helper function for the AppE case. This function proves that we will
-- *always* take a step if a closed term is an application expression.
stepApp :: Exp '[] (t1 :-> t2) -> Exp '[] t1  -> Exp '[] t2
--stepApp (IntE x)       e2 = error "Type error"
stepApp (VarE n)       e2 = case n of {}
stepApp (LamE t e1)    e2 = S.subst (S.singleSub e2) e1
stepApp (AppE e1' e2') e2 = AppE (stepApp e1' e2') e2
--stepApp (TyLam e)      e2 = error "Type error"
stepApp (TyApp e1 t1)  e2 = AppE (stepTyApp e1 t1) e2

-- | Helper function for the TyApp case. This function proves that we will
-- *always* take a step if a closed term is a type application expression.
stepTyApp :: Exp '[] (PolyTy t1) -> Π t -> Exp '[] (W.Subst (W.SingleSub t) t1)
--stepTyApp (IntE x)       e2 = error "Type error"
stepTyApp (VarE n)       t1 = case n of {}
--stepTyApp (LamE t e1)    t1 = error "Type error"
stepTyApp (AppE e1' e2') t1 = TyApp (stepApp e1' e2') t1
stepTyApp (TyLam e1)     t1 = substTy (W.sSingleSub t1) e1
stepTyApp (TyApp e1 t2)  t1 = TyApp (stepTyApp e1 t2) t1


-- | Big-step evaluation of closed terms
-- To do this correctly, we need to define a separate type
-- for values. 
data Val :: [Ty] -> Ty -> Type where
  IntV :: Int -> Val g IntTy
  LamV :: Π (t1 :: Ty)          -- type of binder
        -> Exp (t1:g) t2        -- body of abstraction
        -> Val g (t1 :-> t2)
  TyLamV :: Exp (IncList g) t   -- bind a type variable
         -> Val g (PolyTy t)

eval :: Exp '[] t -> Val '[] t
eval (IntE x) = IntV x
eval (VarE n) = case n of {}
eval (LamE t e) = LamV t e
eval (AppE e1 e2) =
  case eval e1 of
    (LamV t e1') -> eval (S.subst (S.singleSub e2) e1')
eval (TyLam e) = TyLamV e
eval (TyApp e1 t) =
  case eval e1 of
    (TyLamV e1') -> eval (substTy (W.sSingleSub t) e1')



-- | Open, parallel reduction (i.e. reduce under lambda expressions)
-- This doesn't fully reduce the lambda term to normal form in one step
reduce :: forall g t. Exp g t -> Exp g t 
reduce (IntE x)     = IntE x
reduce (VarE n)     = VarE n
reduce (LamE t e)   = LamE t (reduce e)
reduce (TyLam e)    = TyLam (reduce e)
reduce (AppE e1 e2) = case reduce e1 of
  -- IntE x     -> error "type error" 
  -- TyLam e    -> error "type error"
  LamE t e1' -> S.subst (S.singleSub (reduce e2)) e1'
  e1'        -> AppE e1' (reduce e2)
reduce (TyApp e1 (t :: STy t1)) 
  | Refl <- axiom6 @t1 @g
  = case reduce e1 of
      -- IntE x    -> error "type error" 
      -- LamE t e1 -> error "type error" 
      TyLam e1' -> substTy (W.sSingleSub t) e1'
      e1'       -> TyApp e1' t



