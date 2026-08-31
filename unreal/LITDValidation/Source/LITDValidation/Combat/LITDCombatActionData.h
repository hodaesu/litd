#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "Combat/LITDCombatTypes.h"
#include "LITDCombatActionData.generated.h"

class UAnimMontage;

/**
 * Authoritative gameplay description of one combat action.
 * Timings and transitions are gameplay data. The montage is presentation only.
 */
UCLASS(BlueprintType)
class LITDVALIDATION_API ULITDCombatActionData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Combat")
    FName ActionId = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Combat")
    ELITDCombatInput Input = ELITDCombatInput::None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Combat|Timing", meta=(ClampMin="0.0"))
    float StartupSeconds = 0.10f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Combat|Timing", meta=(ClampMin="0.0"))
    float ActiveSeconds = 0.10f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Combat|Timing", meta=(ClampMin="0.0"))
    float RecoverySeconds = 0.30f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Combat|Timing", meta=(ClampMin="0.0"))
    float InputBufferSeconds = 0.15f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Combat|Windows")
    TArray<FLITDCombatWindow> Windows;

    /** Optional simple chains such as Light -> Light or Light -> Heavy. No stance graph. */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Combat|Transitions")
    TArray<FLITDCombatTransition> Transitions;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Combat|Hit")
    FLITDHitProfile HitProfile;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Combat|Targeting")
    FLITDTargetingProfile Targeting;

    /** Visual reference only. Runtime combat legality never reads montage time. */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Presentation")
    TSoftObjectPtr<UAnimMontage> PresentationMontage;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Presentation", meta=(ClampMin="0.01"))
    float PresentationPlayRate = 1.0f;

    UFUNCTION(BlueprintPure, Category="Combat")
    float GetTotalDuration() const;

    UFUNCTION(BlueprintPure, Category="Combat")
    ELITDCombatActionPhase GetPhaseAtTime(float TimeSeconds) const;

    UFUNCTION(BlueprintPure, Category="Combat")
    bool IsWindowOpen(FName WindowName, float TimeSeconds) const;

    const FLITDCombatTransition* FindTransition(ELITDCombatInput RequestedInput, float TimeSeconds) const;
};
