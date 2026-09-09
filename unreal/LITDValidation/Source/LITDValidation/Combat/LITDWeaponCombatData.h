#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "Combat/LITDCombatTypes.h"
#include "LITDWeaponCombatData.generated.h"

class ULITDCombatActionData;

/**
 * Defines the combat actions provided by an equipped weapon.
 * No stance system: the player only requests Light, Heavy, Parry, Dodge or SkillAttack.
 */
UCLASS(BlueprintType)
class LITDVALIDATION_API ULITDWeaponCombatData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Weapon")
    FName WeaponProfileId = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Weapon")
    FName WeaponFamily = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Weapon")
    TArray<TObjectPtr<ULITDCombatActionData>> Actions;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Weapon|Inputs")
    FName LightActionId = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Weapon|Inputs")
    FName HeavyActionId = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Weapon|Inputs")
    FName ParryActionId = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Weapon|Inputs")
    FName DodgeActionId = NAME_None;

    /** Optional weapon-specific skill attack. If empty, runtime falls back to the global skill action registry. */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Weapon|Inputs")
    FName SkillAttackActionId = NAME_None;

    UFUNCTION(BlueprintPure, Category="Weapon")
    FName ResolveDefaultActionId(ELITDCombatInput Input) const;
};
