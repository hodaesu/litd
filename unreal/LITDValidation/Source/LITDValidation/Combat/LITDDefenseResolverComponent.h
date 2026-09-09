#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Combat/LITDCombatTypes.h"
#include "LITDDefenseResolverComponent.generated.h"

class ULITDCombatRuntimeComponent;

/** Sekiro-inspired rule layer: dangerous attacks require the appropriate response instead of universal dodge spam. */
UCLASS(ClassGroup=(LITD), meta=(BlueprintSpawnableComponent))
class LITDVALIDATION_API ULITDDefenseResolverComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintPure, Category="Defense")
    ELITDDefenseOutcome ResolveThreat(ELITDAttackThreatType Threat, const ULITDCombatRuntimeComponent* Runtime) const;

    UFUNCTION(BlueprintPure, Category="Defense")
    ELITDDefenseOutcome ResolveThreatFromWindows(ELITDAttackThreatType Threat, bool bBlock, bool bPerfectParry, bool bDodge, bool bPerfectDodge, bool bSupernaturalGuard) const;

    UFUNCTION(BlueprintPure, Category="Defense")
    float GetBlockedEquilibriumMultiplier(ELITDAttackThreatType Threat) const;
};
