import Relation.Binary as RB
open import Level

module Example where

  module TwoPoint where

    import Relation.Binary.PropositionalEquality as P

    data LH : Set where
      L H : LH

    data _⊑ᴸᴴ_ : LH → LH → Set where
      ⊑ᴸᴴ-H : ∀ {ℓ} → ℓ ⊑ᴸᴴ H
      ⊑ᴸᴴ-L : L ⊑ᴸᴴ L

    ⊑ᴸᴴ-refl : RB.Reflexive _⊑ᴸᴴ_
    ⊑ᴸᴴ-refl {L} = ⊑ᴸᴴ-L
    ⊑ᴸᴴ-refl {H} = ⊑ᴸᴴ-H

    ⊑ᴸᴴ-trans : RB.Transitive _⊑ᴸᴴ_
    ⊑ᴸᴴ-trans a ⊑ᴸᴴ-H = ⊑ᴸᴴ-H
    ⊑ᴸᴴ-trans a ⊑ᴸᴴ-L = a

    _≡ᴸᴴ_ : LH → LH → Set
    _≡ᴸᴴ_ = P._≡_

    ⊑ᴸᴴ-Preorder : RB.Preorder 0ℓ 0ℓ 0ℓ
    ⊑ᴸᴴ-Preorder = record { Carrier = LH
                          ; _≈_ = _≡ᴸᴴ_
                          ; _∼_ = _⊑ᴸᴴ_
                          ; isPreorder = record { isEquivalence = P.isEquivalence
                                                ; reflexive     = λ {P.refl → ⊑ᴸᴴ-refl}
                                                ; trans         = ⊑ᴸᴴ-trans } }

  open TwoPoint

  open import NBELMon (⊑ᴸᴴ-Preorder)
  open import Data.Empty
  open import Relation.Nullary

  main : ¬ (Nf (〈 𝕓 〉 L) ( Ø `, (〈 𝕓 〉 H)))
  main nf with Nf-Prot (Ø `, flows ⊑ᴸᴴ-refl) (⟨ 𝕓 ⟩ L) (〈 𝕓 〉 L) nf
  main nf | flows ()
  main nf | layer ()

  main₂ : ¬ (Nf (〈 𝕓 〉 H ⇒ 〈 𝕓 〉 L) Ø)
  main₂ (`λ nf) = main nf
  main₂ (case x n₁ n₂) = emptyNe x

  Bool : Type
  Bool = 𝟙 + 𝟙

  True : ∀ {Γ} → Nf Bool Γ
  True = inl unit

  False : ∀ {Γ} → Nf Bool Γ
  False = inr unit

  open import Relation.Binary.PropositionalEquality
  open import Data.Sum

  private
    lemma₁ : ∀ {a b} → ¬ (Ne (a ⇒ b) (Ø `, (〈 Bool 〉 H)))
    lemma₁ n with neutrality n
    lemma₁ n | here ()
    lemma₁ n | there ()

    lemma₂ : ∀ {a b} → ¬ (Ne (a + b) (Ø `, (〈 Bool 〉 H)))
    lemma₂ n with neutrality n
    lemma₂ n | here ()
    lemma₂ n | there ()

  main₃ : (n : Nf (〈 Bool 〉 H ⇒ Bool) Ø)
        → (n ≡ `λ True) ⊎ (n ≡ `λ False)
  main₃ (`λ (inl unit))         = inj₁ refl
  main₃ (`λ (inl (case n _ _))) = ⊥-elim (lemma₂ n)
  main₃ (`λ (inr unit))         = inj₂ refl
  main₃ (`λ (inr (case n _ _))) = ⊥-elim (lemma₂ n)
  main₃ (`λ (case n _ _))       = ⊥-elim (lemma₂ n)
  main₃ (case n _ _)            = ⊥-elim (emptyNe n)

  private
    lemma₃ : ∀ {a} {ℓ} → ℓ ⊑ L → ¬ (Ne (〈 a 〉 ℓ) (Ø `, (〈 Bool 〉 H)))
    lemma₃ p n with neutrality n
    lemma₃ () n | here _⊲_.refl
    lemma₃ p n | there ()

  main₄ : (n : Nf (〈 Bool 〉 H ⇒ 〈 Bool 〉 L) Ø)
        → (n ≡ `λ (η True)) ⊎ (n ≡ `λ (η False))
  main₄ (`λ (η (inl unit)))         = inj₁ refl
  main₄ (`λ (η (inl (case n _ _)))) = ⊥-elim (lemma₂ n)
  main₄ (`λ (η (inr unit)))         = inj₂ refl
  main₄ (`λ (η (inr (case n _ _)))) = ⊥-elim (lemma₂ n)
  main₄ (`λ (η (case n _ _)))       = ⊥-elim (lemma₂ n)
  main₄ (`λ (p ↑ n ≫= _))          = ⊥-elim (lemma₃ p n)
  main₄ (`λ (case n _ _))           = ⊥-elim (lemma₂ n)
  main₄ (case n _ _)                = ⊥-elim (emptyNe n)

  main₅ : (t : Term (〈 Bool 〉 H ⇒ 〈 Bool 〉 L) Ø)
        → (norm t ≡ `λ (η True)) ⊎ (norm t ≡ `λ (η False))
  main₅ t = main₄ (norm t)
 
