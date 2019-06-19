{-# OPTIONS --allow-unsolved-metas #-}
import Relation.Binary as RB
open import Level using (0ℓ)

module NBELMon (Pre : RB.Preorder 0ℓ 0ℓ 0ℓ)where

  Label   = RB.Preorder.Carrier Pre

  _⊑_     = RB.Preorder._∼_ Pre
  ⊑-refl  = RB.Preorder.refl Pre
  ⊑-trans = RB.Preorder.trans Pre

  module TypeModule where

    data Type  : Set where
      𝟙     :                 Type
      𝕓     :                 Type
      _⇒_   : (a b : Type)  → Type
      _+_   : (a b : Type)  → Type
      〈_〉_   : (ℓ : Label) (a : Type) → Type

    infixr 10 _⇒_

    -- Ctx as a snoc list of types
    data Ctx : Set where
      Ø    : Ctx
      _`,_ : Ctx → Type → Ctx

  open TypeModule public

  module Weakening where

    -- Weakening over contexts Γ ⊆ Δ to be read as:
    -- Γ is weaker (contains possibly more types) than Δ
    -- Δ is thinner (contains possibly less types) than Γ
    data _⊆_ : Ctx → Ctx → Set where
      base : Ø ⊆ Ø
      keep : ∀ {T Γ Δ} → Γ ⊆ Δ → (Γ `, T) ⊆ (Δ `, T)
      drop : ∀ {T Γ Δ} → Γ ⊆ Δ → (Γ `, T) ⊆ Δ

    -- Weakenings are a preorder relation
    ⊆-refl : RB.Reflexive _⊆_
    ⊆-refl {Ø}      = base
    ⊆-refl {Γ `, T} = keep ⊆-refl

    ⊆-trans : RB.Transitive _⊆_
    ⊆-trans base q = q
    ⊆-trans (keep p) (keep q) = keep (⊆-trans p q)
    ⊆-trans (keep p) (drop q) = drop (⊆-trans p q)
    ⊆-trans (drop p) q        = drop (⊆-trans p q)

  open Weakening public

  module Variable where

    -- De Bruijn index into a context
    data _∈_ : Type → Ctx → Set where
      ze : ∀ {Γ a}   → a ∈ (Γ `, a)
      su : ∀ {Γ a S} → a ∈ Γ → a ∈ (Γ `, S)

    wkenV : ∀ {a} {Γ Δ} → Γ ⊆ Δ → a ∈ Δ → a ∈ Γ
    wkenV (keep e) ze     = ze
    wkenV (keep e) (su v) = su (wkenV e v)
    wkenV (drop e) v      = su (wkenV e v)

  open Variable public

  module TermM where

    data Term : Type → Ctx → Set where
      unit  : ∀ {Γ} → Term 𝟙 Γ
      `λ    : ∀ {Γ} {a b} → Term b (Γ `, a) → Term (a ⇒ b) Γ
      var   : ∀ {Γ} {a}   → a ∈ Γ → Term a Γ
      _∙_   : ∀ {Γ} {a b} → Term (a ⇒ b) Γ → Term a Γ → Term b Γ
      _↑_   : ∀ {ℓᴸ ℓᴴ} {Γ} {a} → ℓᴸ ⊑ ℓᴴ → Term (〈 ℓᴸ 〉 a) Γ → Term (〈 ℓᴴ 〉 a) Γ
      η     : ∀ {ℓ} {Γ} {a}    → Term a Γ → Term (〈 ℓ 〉 a) Γ
      _≫=_ : ∀ {ℓ} {Γ} {a b} → Term (〈 ℓ 〉 a) Γ → Term (〈 ℓ 〉 b) (Γ `, a) → Term (〈 ℓ 〉 b) Γ
      inl   : ∀ {Γ} {a b} → Term a Γ → Term (a + b) Γ
      inr   : ∀ {Γ} {a b} → Term b Γ → Term (a + b) Γ
      case  : ∀ {Γ} {a b c} → Term (a + b) Γ → Term c (Γ `, a) → Term c (Γ `, b) → Term c Γ
    
    wkenTm : ∀ {a} {Γ Δ} → Γ ⊆ Δ → Term a Δ → Term a Γ
    wkenTm e unit = unit
    wkenTm e (`λ t)    = `λ (wkenTm (keep e) t)
    wkenTm e (var x)   = var (wkenV e x)
    wkenTm e (t ∙ t₁)  = wkenTm e t ∙ wkenTm e t₁
    wkenTm e (η t)     = η (wkenTm e t)
    wkenTm e (t ≫= k) = wkenTm e t ≫= wkenTm (keep e) k
    wkenTm e (x ↑ t)   = x ↑ wkenTm e t
    wkenTm e (inl t) = inl (wkenTm e t)
    wkenTm e (inr t) = inr (wkenTm e t)
    wkenTm e (case t t₁ t₂) = case (wkenTm e t) (wkenTm (keep e) t₁) (wkenTm (keep e) t₂)

  open TermM public

  module NormalForm where

  mutual

    data Ne : Type → Ctx → Set where
      var   : ∀ {Γ} {a}   → a ∈ Γ → Ne a Γ
      _∙_   : ∀ {Γ} {a b} → Ne (a ⇒ b) Γ → Nf a Γ → Ne b Γ

    data Nf : Type → Ctx → Set where
      unit    : ∀ {Γ} → Nf 𝟙 Γ 
      `λ      : ∀ {Γ} {a b}      → Nf b (Γ `, a) → Nf (a ⇒ b) Γ
      𝕓       : ∀ {Γ}            → Ne 𝕓 Γ   → Nf 𝕓 Γ
      η       : ∀ {ℓ} {Γ}  {a}   → Nf a Γ → Nf (〈 ℓ 〉 a) Γ
      _↑_≫=_ : ∀ {ℓᴸ ℓᴴ} {Γ} {a b}  → ℓᴸ ⊑ ℓᴴ → Ne (〈 ℓᴸ 〉 a) Γ → Nf (〈 ℓᴴ 〉 b) (Γ `, a) → Nf (〈 ℓᴴ 〉 b) Γ
      inl     : ∀ {Γ} {a b} → Nf a Γ → Nf (a + b) Γ
      inr     : ∀ {Γ} {a b} → Nf b Γ → Nf (a + b) Γ
      case    : ∀ {Γ} {a b c} → Ne (a + b) Γ → Nf c (Γ `, a) → Nf c (Γ `, b) → Nf c Γ

    wkenNe : ∀ {a} {Γ Δ} → Γ ⊆ Δ → Ne a Δ → Ne a Γ
    wkenNe e (var x) = var (wkenV e x)
    wkenNe e (n ∙ x) = (wkenNe e n) ∙ (wkenNf e x)

    wkenNf : ∀ {a} {Γ Δ} → Γ ⊆ Δ → Nf a Δ → Nf a Γ
    wkenNf e unit           = unit
    wkenNf e (`λ n)         = `λ (wkenNf (keep e) n)
    wkenNf e (η m)          = η (wkenNf e m)
    wkenNf e (𝕓 n)          = 𝕓 (wkenNe e n)
    wkenNf e (p ↑ x ≫= m)  = p ↑ (wkenNe e x) ≫= wkenNf (keep e) m
    wkenNf e (inl n)        = inl (wkenNf e n)
    wkenNf e (inr n)        = inr (wkenNf e n)
    wkenNf e (case x n₁ n₂) = case (wkenNe e x) (wkenNf (keep e) n₁) (wkenNf (keep e) n₂)

    qNf : ∀ {a} {Γ} → Nf a Γ → Term a Γ
    qNf unit           = unit
    qNf (`λ n)         = `λ (qNf n)
    qNf (𝕓 x)          = qNe x
    qNf (η n)          = η (qNf n)
    qNf (p ↑ x ≫= n)  = (p ↑ (qNe x)) ≫= (qNf n)
    qNf (inl n)        = inl (qNf n)
    qNf (inr n)        = inr (qNf n)
    qNf (case n c₁ c₂) = case (qNe n) (qNf c₁) (qNf c₂)

    qNe : ∀ {a} {Γ} → Ne a Γ → Term a Γ
    qNe (var x) = var x
    qNe (t ∙ u) = (qNe t) ∙ (qNf u)

  open NormalForm public

  open import Data.Product
  open import Data.Unit hiding (_≤_)
  open import Data.Sum
    using (_⊎_ ; inj₁ ; inj₂ ; [_,_]′)
  open import Function using (_∘_)

  module Presheaf where
  {- Machinery for interpretations -}

    record 𝒫 : Set₁ where
      field
        In   : Ctx → Set
        Wken : ∀ {Δ Γ} (Γ⊆Δ : Γ ⊆ Δ) → (In Δ → In Γ)

    open 𝒫

    -- natural transformation
    _→∙_ : 𝒫 → 𝒫 → Set
    (P →∙ Q) = ∀ {Γ} → P .In Γ → Q .In Γ

    _×ᴾ_ : 𝒫 → 𝒫 → 𝒫
    In (P ×ᴾ Q) Γ                 = (In P Γ) × (In Q Γ)
    Wken (P ×ᴾ Q) Γ⊆Δ (fst , snd) = (Wken P Γ⊆Δ fst) , (Wken Q Γ⊆Δ snd)

    _⇒ᴾ_ :  𝒫 → 𝒫 → 𝒫
    In (P ⇒ᴾ Q) Γ             = ∀ {Δ} → Δ ⊆ Γ → P .In Δ → Q .In Δ
    (P ⇒ᴾ Q) .Wken Γ⊆Δ₁ f Δ⊆Γ = f (⊆-trans Δ⊆Γ  Γ⊆Δ₁)

    _+ᴾ_ :  𝒫 → 𝒫 → 𝒫
    In (P +ᴾ Q) Γ    = (In P Γ) ⊎ (In Q Γ)
    (P +ᴾ Q) .Wken Γ⊆Δ = [ inj₁ ∘ Wken P Γ⊆Δ , inj₂ ∘ Wken Q Γ⊆Δ  ]′ 

    𝟙ᴾ : 𝒫
    𝟙ᴾ = record { In = λ _ → ⊤ ; Wken = λ {Δ} {Γ} Γ⊆Δ _ → tt }

  open Presheaf
  open 𝒫

  module CoverMonad where

    data 𝒞 (A : 𝒫) (ℓ : Label) : Ctx → Set where
      return : ∀ {Γ}       → A .In Γ → 𝒞 A ℓ Γ
      bind   : ∀ {Γ} {a} {ℓᴸ}  → ℓᴸ ⊑ ℓ → Ne (〈 ℓᴸ 〉 a) Γ → 𝒞 A ℓ (Γ `, a) → 𝒞 A ℓ Γ
      branch : ∀ {Γ} {a b} → Ne (a + b) Γ →  𝒞 A ℓ (Γ `, a) →  𝒞 A ℓ (Γ `, b) → 𝒞 A ℓ Γ

    wken𝒞 : ∀ {ℓ} {A} {Γ Δ} → Γ ⊆ Δ → 𝒞 A ℓ Δ → 𝒞 A ℓ Γ
    wken𝒞 {A = A} e (return x) = return (Wken A e x)
    wken𝒞 e (bind p x m)        = bind p  (wkenNe e x) (wken𝒞 (keep e) m)
    wken𝒞 e (branch x m₁ m₂)    = branch (wkenNe e x) (wken𝒞 (keep e) m₁) (wken𝒞 (keep e) m₂)

    {- The cover monad is a presheaf -}
    𝒞ᴾ : Label → 𝒫 → 𝒫
    𝒞ᴾ ℓ A = record { In = 𝒞 A ℓ ; Wken = wken𝒞 }

    {- We can implement functorial map -}
    map𝒞  : ∀ {ℓ} {A B} → (A →∙ B) → (𝒞ᴾ ℓ A →∙ 𝒞ᴾ ℓ B)
    map𝒞 f (return x) = return (f x)
    map𝒞 f (bind p x m) = bind p x (map𝒞 f m)
    map𝒞 f (branch x c₁ c₂) = branch x (map𝒞 f c₁) (map𝒞 f c₂)

    {- And derive μ -}
    join𝒞 : ∀ {ℓ} {A} → 𝒞ᴾ ℓ (𝒞ᴾ ℓ A) →∙ 𝒞ᴾ ℓ A
    join𝒞 (return x) = x
    join𝒞 (bind p f m) = bind p f (join𝒞 m)
    join𝒞 (branch x c₁ c₂) = branch x (join𝒞 c₁) (join𝒞 c₂)

    mapExp𝒞  : ∀ {ℓ} {A B} → (A ⇒ᴾ B) →∙ (𝒞ᴾ ℓ A ⇒ᴾ 𝒞ᴾ ℓ B)
    mapExp𝒞 f e (return x) = return (f e x)
    mapExp𝒞 f e (bind p x m) = bind p x (mapExp𝒞 f (drop e) m)
    mapExp𝒞 f e (branch x c₁ c₂) = branch x (mapExp𝒞 f (drop e) c₁) (mapExp𝒞 f (drop e) c₂)

    bindExp𝒞 : ∀ {ℓ} {A B} → (A ⇒ᴾ 𝒞ᴾ ℓ B) →∙ (𝒞ᴾ ℓ A ⇒ᴾ 𝒞ᴾ ℓ B)
    bindExp𝒞 f e m = join𝒞 (mapExp𝒞 f e m)

    up𝒞 : ∀ {ℓᴸ ℓᴴ} {A} → ℓᴸ ⊑ ℓᴴ → (𝒞ᴾ ℓᴸ A →∙ 𝒞ᴾ ℓᴴ A)
    up𝒞 L⊑H (return x)  = return x
    up𝒞 L⊑H (bind p n k)  = bind (⊑-trans p L⊑H) n (up𝒞 L⊑H k)
    up𝒞 L⊑H (branch x c₁ c₂) = branch x (up𝒞 L⊑H c₁) (up𝒞 L⊑H c₂)

  open CoverMonad public

  -- decision monad for coproducts
  module DecMonad where

  data 𝒟 (A : 𝒫) : Ctx → Set where
    return : ∀ {Γ} → A .In Γ → 𝒟 A Γ
    branch : ∀ {Γ} {a b}
      → Ne (a + b) Γ
      → (c₁ : 𝒟 A (Γ `, a)) → (c₂ :  𝒟 A (Γ `, b))
      ---------------------------------------------
      → 𝒟 A Γ

  wken𝒟 : ∀ {A} {Γ Δ} → Γ ⊆ Δ → 𝒟 A Δ → 𝒟 A Γ
  wken𝒟 {A} e (return x) = return (Wken A e x)
  wken𝒟 e (branch x c₁ c₂) = branch (wkenNe e x) (wken𝒟 (keep e) c₁) (wken𝒟 (keep e) c₂)

  𝒟ᴾ : 𝒫 → 𝒫
  𝒟ᴾ A = record { In = 𝒟 A ; Wken = wken𝒟 }

  map𝒟  : ∀ {A B} → (A →∙ B) → (𝒟ᴾ A →∙ 𝒟ᴾ B)
  map𝒟 f (return x) = return (f x)
  map𝒟 f (branch x c₁ c₂) = branch x (map𝒟 f c₁) (map𝒟 f c₂)

  join𝒟 : ∀ {A} → 𝒟ᴾ (𝒟ᴾ A) →∙ 𝒟ᴾ A
  join𝒟 (return x) = x
  join𝒟 (branch x m m₁) = branch x (join𝒟 m) (join𝒟 m₁)

  mapExp𝒟  : ∀ {A B} → (A ⇒ᴾ B) →∙ (𝒟ᴾ A ⇒ᴾ 𝒟ᴾ B)
  mapExp𝒟 f e (return x) =
    return (f e x)
  mapExp𝒟 f e (branch x c₁ c₂) =
    branch x (mapExp𝒟 f (drop e) c₁) (mapExp𝒟 f (drop e) c₂)

  bindExp𝒟 : ∀ {A B} → (A ⇒ᴾ 𝒟ᴾ B) →∙ (𝒟ᴾ A ⇒ᴾ 𝒟ᴾ B)
  bindExp𝒟 f e m = join𝒟 (mapExp𝒟 f e m)

  open DecMonad

  module Interpretation where

    Termᴾ : Type → 𝒫
    Termᴾ τ = record { In = Term τ ; Wken = wkenTm }

    Nfᴾ : Type → 𝒫
    Nfᴾ τ = record { In = Nf τ ; Wken = wkenNf }

    Neᴾ : Type → 𝒫
    Neᴾ τ = record { In = Ne τ ; Wken = wkenNe }

    𝕓ᴾ : 𝒫
    𝕓ᴾ = record { In   = Nf 𝕓 ; Wken = wkenNf }

    ⟦_⟧ : Type → 𝒫
    ⟦ 𝟙  ⟧        = 𝟙ᴾ
    ⟦ 𝕓 ⟧         = 𝕓ᴾ
    ⟦ a ⇒ b ⟧     = ⟦ a ⟧ ⇒ᴾ  ⟦ b ⟧
    ⟦ 〈 ℓ 〉 a ⟧  = 𝒞ᴾ ℓ ⟦ a ⟧
    ⟦ a + b ⟧     = 𝒟ᴾ (⟦ a ⟧ +ᴾ ⟦ b ⟧)

    ⟦_⟧ₑ : Ctx → 𝒫
    ⟦ Ø ⟧ₑ      = 𝟙ᴾ
    ⟦ Γ `, a ⟧ₑ = ⟦ Γ ⟧ₑ ×ᴾ ⟦ a ⟧

  open Interpretation public

  module DecMonadOps where

  run𝒟Nf : ∀ {a : Type} → 𝒟ᴾ (Nfᴾ a) →∙ (Nfᴾ a)
  run𝒟Nf (return x) = x
  run𝒟Nf (branch x m m₁) = case x (run𝒟Nf m) (run𝒟Nf m₁)

  run𝒟 : ∀ {a : Type} → 𝒟ᴾ ⟦ a ⟧ →∙ ⟦ a ⟧
  run𝒟 {𝟙}      _ = tt
  run𝒟 {𝕓}      m = run𝒟Nf m
  run𝒟 {a + b}  m = join𝒟 m
  run𝒟 {a ⇒ b}  m = λ e x → run𝒟 {b} (run𝒟⇒ m e (return x))
    where
    run𝒟⇒ : 𝒟ᴾ ⟦ a ⇒ b ⟧ →∙ (𝒟ᴾ ⟦ a ⟧ ⇒ᴾ 𝒟ᴾ ⟦ b ⟧)
    run𝒟⇒ (return f) e x = mapExp𝒟 f e x
    run𝒟⇒ (branch n c₁ c₂) e x =
      branch (wkenNe e n)
        (run𝒟⇒ c₁ (keep e) (wken𝒟 (drop ⊆-refl) x))
        (run𝒟⇒ c₂ (keep e) (wken𝒟 (drop ⊆-refl) x))
  run𝒟 {〈 ℓ 〉 a} m = run𝒟𝒞 m
    where
    run𝒟𝒞 : 𝒟ᴾ (𝒞ᴾ ℓ ⟦ a ⟧) →∙ (𝒞ᴾ ℓ ⟦ a ⟧)
    run𝒟𝒞 (return x) = x
    run𝒟𝒞 (branch x c₁ c₂) = branch x (run𝒟𝒞 c₁) (run𝒟𝒞 c₂)

  open DecMonadOps
  module NbE where

    open 𝒫

    lookup : ∀ {a Γ} → a ∈ Γ → (⟦ Γ ⟧ₑ →∙ ⟦ a ⟧)
    lookup ze     (_ , v) = v
    lookup (su v) (γ , _) = lookup v γ

    eval : ∀ {a Γ} → Term a Γ → (⟦ Γ ⟧ₑ →∙ ⟦ a ⟧)
    eval unit _ = tt
    eval {Γ = Γ} (`λ t) γ     = λ e u → eval t (Wken ⟦ Γ ⟧ₑ e γ , u)
    eval (var x) γ            = lookup x γ
    eval (t ∙ u) γ            = (eval t γ) ⊆-refl (eval u γ)
    eval (η t) γ              = return (eval t γ)
    eval {Γ = Γ} (t ≫= m) γ  = bindExp𝒞 (λ e a → eval m (Wken ⟦ Γ ⟧ₑ e γ , a)) ⊆-refl (eval t γ)
    eval (c ↑ t) γ            = up𝒞 c (eval t γ)
    eval (inl t) γ            = return (inj₁ (eval t γ))
    eval (inr t) γ            = return (inj₂ (eval t γ))
    eval {a} {Γ} (case {_} {b} {c} t t₁ t₂) {Δ} γ =
      run𝒟 {a} (mapExp𝒟 match ⊆-refl (eval t γ))
      where
      match : ((⟦ b ⟧ +ᴾ ⟦ c ⟧) ⇒ᴾ ⟦ a ⟧) .In Δ
      match e (inj₁ x) = eval t₁ ((Wken ⟦ Γ ⟧ₑ e γ) , x)
      match e (inj₂ y) = eval t₂ ((Wken ⟦ Γ ⟧ₑ e γ) , y)

    mutual

      reifyVal : ∀ {a} → ⟦ a ⟧ →∙ Nfᴾ a
      reifyVal {𝟙} x      = unit
      reifyVal {𝕓} x      = x
      reifyVal {a ⇒ b} f  = `λ (reifyVal (f (drop ⊆-refl) (reflect {a} (var ze))))
      reifyVal {〈 a 〉 ℓ} m = reifyVal𝒞 m
      reifyVal {a + b}  m = run𝒟Nf (map𝒟 reifySum m)

      reifyVal𝒟 : ∀ {a} → 𝒟ᴾ ⟦ a ⟧ →∙ Nfᴾ a
      reifyVal𝒟 {a} m = run𝒟Nf {a} (map𝒟 reifyVal m)

      reifySum : ∀ {a b} → (⟦ a ⟧ +ᴾ ⟦ b ⟧) →∙ Nfᴾ (a + b)
      reifySum {a} {b} = [ inl ∘ reifyVal {a} , inr ∘ reifyVal {b} ]′

      reifyVal𝒞 : ∀ {a} {ℓ} → 𝒞ᴾ ℓ ⟦ a ⟧ →∙ Nfᴾ (〈 ℓ 〉 a)
      reifyVal𝒞 (return x) = η (reifyVal x)
      reifyVal𝒞 (bind p x m) = p ↑ x ≫= reifyVal𝒞 m
      reifyVal𝒞 (branch x c₁ c₂) = case x (reifyVal𝒞 c₁) (reifyVal𝒞 c₂)

      reflect : ∀ {a} → Neᴾ a →∙ ⟦ a ⟧
      reflect {𝟙}      n = tt
      reflect {𝕓}      n = 𝕓 n
      reflect {a ⇒ b}  n = λ e v → reflect ((wkenNe e n) ∙ (reifyVal v))
      reflect {〈 ℓ 〉 a} n =  bind ⊑-refl n (return (reflect {a} (var ze)))
      reflect {a + b}  n =
        branch n
          (return (inj₁ (reflect {a} (var ze))))
          (return (inj₂ (reflect {b} (var ze))))

      idSubst :  ∀ Γ → ⟦ Γ ⟧ₑ .In Γ
      idSubst Ø        = tt
      idSubst (Γ `, T) = Wken ⟦ Γ ⟧ₑ (drop ⊆-refl) (idSubst Γ) , reflect {T} (var ze)

      reify : ∀{a Γ} → (⟦ Γ ⟧ₑ →∙ ⟦ a ⟧) → Nf a Γ
      reify {a} {Γ} f = reifyVal (f (idSubst Γ))

      norm : ∀ {a} → Termᴾ a →∙ Nfᴾ a
      norm t = reify (eval t)

  open NbE public

  module Const where

    open import Relation.Binary.PropositionalEquality

    ⊆-term : ∀ {Γ} → Γ ⊆ Ø
    ⊆-term {Ø} = base
    ⊆-term {Γ `, x} = drop ⊆-term
    
    IsConstTm : ∀ {Γ a} → Term a Γ → Set
    IsConstTm {Γ} {a} t = Σ (Term a Ø) λ t' → wkenTm ⊆-term t' ≡ t

    IsConstNf : ∀ {Γ a} → Nf a Γ → Set
    IsConstNf {Γ} {a} n = Σ (Nf a Ø) λ n' → wkenNf ⊆-term n' ≡ n
    
    -- Example: True is a constant
    private
    
      Bool : Type
      Bool = 𝟙 + 𝟙

      True : ∀ {Γ} → Nf Bool Γ
      True = inl unit

      TrueIsConst : ∀ {Γ} → IsConstNf {Γ} True
      TrueIsConst = (inl unit) , refl

  open Const public

  module NI where

    open import Relation.Binary.PropositionalEquality

    -- Transparency
    
    data Tr : Type → Label → Set where
      𝟙 : ∀ {ℓ}   → Tr 𝟙 ℓ
      𝕓   : ∀ {ℓ} → Tr 𝕓 ℓ
      _+_ : ∀ {a b} {ℓ}  → Tr a ℓ → Tr b ℓ → Tr (a + b) ℓ
      ⇒_ : ∀ {a b} {ℓ}  → Tr b ℓ → Tr (a ⇒ b) ℓ
      〈_〉_ : ∀ {a} {ℓ ℓ'} → Tr a ℓ' → ℓ' ⊑ ℓ → Tr (〈 ℓ' 〉 a) ℓ

    -- Protected at
    
    data Pr : Type → Label → Set where
      ⇒_    : ∀ {ℓ} {a b}    → Pr b ℓ  → Pr (a ⇒ b) ℓ
      lower : ∀ {ℓ} {ℓ'} {a} → ℓ ⊑ ℓ' → Pr (〈 ℓ' 〉 a) ℓ
    
    -- Protected at, for context. Defined component-wise.
    
    data Prᶜ : Ctx → Label → Set where
      Ø    : ∀ {ℓ} → Prᶜ Ø ℓ
      _`,_ : ∀ {ℓ} {Γ} {a} → Prᶜ Γ ℓ → Pr a ℓ → Prᶜ (Γ `, a) ℓ

    -- First order type
    
    data Ground : Type → Set where
      𝟙   : Ground 𝟙
      𝕓   : Ground 𝕓
      〈_〉_ : ∀ {a} → Ground a → (ℓ : Label) → Ground (〈 ℓ 〉 a)
      _+_ : ∀ {a b} → Ground a → Ground b → Ground (a + b)

    -- Variables preserve opaqeueness
    
    Var-Pr : ∀ {Γ} {a} {ℓ} → Prᶜ Γ ℓ → a ∈ Γ → Pr a ℓ
    Var-Pr (e `, a) ze = a
    Var-Pr (e `, a) (su v) = Var-Pr e v

    -- Neutrals preserve opaqeueness
    
    Ne-Pr : ∀ {Γ} {a} {ℓ} → Prᶜ Γ ℓ → Ne a Γ → Pr a ℓ
    Ne-Pr e (var x) = Var-Pr e x
    Ne-Pr e (x ∙ n) with (Ne-Pr e x)
    ... | ⇒ p = p

    -- Variable-outputs can only be observed at a higher level
    
    Var-Safe : ∀ {Γ} {a} {ℓⁱ ℓᵒ}
      → Prᶜ Γ ℓⁱ
      → Tr a ℓᵒ
      → a ∈ Γ → (ℓⁱ ⊑ ℓᵒ)
    Var-Safe (p `, ()) 𝟙 ze
    Var-Safe (p `, ()) 𝕓 ze
    Var-Safe (p `, ()) (_ + _) ze
    Var-Safe (p `, (⇒ x)) (⇒ y) ze = Var-Safe (p `, x) y ze
    Var-Safe (p `, lower q) (〈 t 〉 x) ze = ⊑-trans q x
    Var-Safe (p `, x) t (su v) = Var-Safe p t v

    -- Neutral-outputs can only be observed at a higher level
    
    Ne-Safe : ∀ {Γ} {a} {ℓⁱ ℓᵒ}
      → Prᶜ Γ ℓⁱ
      → Tr a ℓᵒ
      → Ne a Γ → (ℓⁱ ⊑ ℓᵒ)
    Ne-Safe e t (var x) = Var-Safe e t x
    Ne-Safe e t (x ∙ _) = Ne-Safe e (⇒ t) x

    ------------------------------------------------------------
    -- (First-order) Normal forms are either constants,
    -- or their output can only be observed at a higher level
    ------------------------------------------------------------

    Nf-Safe : ∀ {Γ} {a} {ℓⁱ ℓᵒ}
    
      -- protected input
      → Prᶜ Γ ℓⁱ
      
      -- transparent, first-order output
      → Ground a → Tr a ℓᵒ

      → (n : Nf a Γ) → IsConstNf n ⊎ (ℓⁱ ⊑ ℓᵒ)

    -- units are constants
    Nf-Safe p g t unit = inj₁ (unit , refl)

    -- return type is not allowed to be a function
    Nf-Safe p () t (`λ n)

    -- base types are safe, by Ne-Safe
    Nf-Safe p g t (𝕓 x) = inj₂ (Ne-Safe p t x)

    -- argument of η is either constant or at a higher level
    Nf-Safe p (〈 g 〉 ℓ) (〈 t 〉 q) (η n) with Nf-Safe p g t n
    ... | inj₁ (n' , r) = inj₁ (η n' , cong η r)
    ... | inj₂ r = inj₂ (⊑-trans r q)

    -- 
    Nf-Safe p g (〈 t 〉 q) (r ↑ x ≫= n) with Ne-Pr p x
    ... | lower s = inj₂ (⊑-trans s (⊑-trans r q))

    -- 
    Nf-Safe p (g + _) (t + _) (inl n) with Nf-Safe p g t n
    ... | inj₁ (n' , r) = inj₁ (inl n' , cong inl r)
    ... | inj₂ r = inj₂ r

    -- 
    Nf-Safe p (_ + g) (_ + t) (inr n) with Nf-Safe p g t n
    ... | inj₁ (n' , r) = inj₁ (inr n' , cong inr r)
    ... | inj₂ r = inj₂ r

    -- sums are not allowed in the context
    Nf-Safe p g t (case x n₁ n₂) with Ne-Pr p x
    ... | ()

    open import Data.Empty
    open import Relation.Nullary

  open NI public

  module Neutrality where

    open import Data.Empty
    open import Relation.Nullary

    emptyNe : ∀ {a} → ¬ (Ne a Ø)
    emptyNe (var ())
    emptyNe (x ∙ _) = emptyNe x

    BinOp = Type → Type → Type

    data _⊲_ : Type → Type → Set where
      refl  : ∀{a} → a ⊲ a
      -- sbl⇒  : ∀ {a b c} → a ⊲ b → a ⊲ (b ⇒ c)
      sbr⇒  : ∀ {a b c} → a ⊲ c → a ⊲ (b ⇒ c)
      -- sbl+  : ∀ {a b c} → a ⊲ b → a ⊲ (b + c)
      -- sbr+  : ∀ {a b c} → a ⊲ c → a ⊲ (b + c)

    postulate
      ⊲-trans : RB.Transitive _⊲_

    data _⊲ᶜ_ : Type → Ctx → Set where
      here  :  ∀ {a b} {Γ} → a ⊲ b  → a ⊲ᶜ (Γ `, b)
      there :  ∀ {a b} {Γ} → a ⊲ᶜ Γ → a ⊲ᶜ (Γ `, b)

    neutrVar : ∀ {a} {Γ} → a ∈ Γ → a ⊲ᶜ Γ
    neutrVar ze = here refl
    neutrVar (su v) = there (neutrVar v)

    neutr⇒ : ∀ {a b c} → (b ⇒ c) ⊲ a → c ⊲ a
    neutr⇒ refl     = sbr⇒ refl
    -- neutr⇒ (sbl⇒ p) = sbl⇒ (neutr⇒ p)
    neutr⇒ (sbr⇒ p) = sbr⇒ (neutr⇒ p)
    -- neutr⇒ (sbr+ p) = sbr+ (neutr⇒ p)
    -- neutr⇒ (sbl+ p) = sbl+ (neutr⇒ p)

    ⊲-lift : ∀ {b a} {Γ} → b ⊲ a → a ⊲ᶜ Γ → b ⊲ᶜ Γ
    ⊲-lift p (here q)  = here (⊲-trans p q)
    ⊲-lift p (there q) = there (⊲-lift p q)

    neutrality : ∀ {a} {Γ} → Ne a Γ → a ⊲ᶜ Γ
    neutrality (var x) = neutrVar x
    neutrality (x ∙ n) = ⊲-lift (sbr⇒ refl) (neutrality x)

  open Neutrality public
