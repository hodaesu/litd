#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "Combat/LITDCombatTypes.h"
#include "LITDCombatStyleData.generated.h"

class ULITDCombatActionData;

USTRUCT(BlueprintType)
struct FLITDStyleEntryAction
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    ELITDCombatStance Stance = ELITDCombatStance::Forward;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    ELITDCombatInput Input = ELITDCombatInput::Light;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    FName ActionId = NAME_None;
};

/** Absolver-inspired combat grammar: each unarmed/weapon style owns actions and stance entry points. */
UCLASS(BlueprintType)
class LITDVALIDATION_API ULITDCombatStyleData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    FName StyleId = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    bool bUnarmed = false;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    TArray<TObjectPtr<ULITDCombatActionData>> Actions;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    TArray<FLITDStyleEntryAction> EntryActions;

    UFUNCTION(BlueprintPure)
    FName ResolveEntryActionId(ELITDCombatStance Stance, ELITDCombatInput Input) const;
};
