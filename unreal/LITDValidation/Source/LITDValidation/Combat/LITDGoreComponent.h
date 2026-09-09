#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Combat/LITDCombatTypes.h"
#include "LITDGoreComponent.generated.h"

USTRUCT(BlueprintType)
struct FLITDBodyPartState
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    ELITDBodyZone Zone = ELITDBodyZone::Torso;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1.0"))
    float Integrity = 100.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="1.0"))
    float SeverThreshold = 60.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    bool bCanSever = false;

    UPROPERTY(BlueprintReadOnly)
    float AccumulatedTrauma = 0.0f;

    UPROPERTY(BlueprintReadOnly)
    bool bSevered = false;
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FLITDLimbSeveredEvent, ELITDBodyZone, Zone, FVector, HitLocation, FVector, Impulse);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FLITDLocalizedHitEvent, ELITDBodyZone, Zone, float, Damage, ELITDDamageNature, DamageNature);

/** Logical gore state only. Mesh hiding, Niagara blood and detached limbs are presentation listeners. */
UCLASS(ClassGroup=(LITD), meta=(BlueprintSpawnableComponent))
class LITDVALIDATION_API ULITDGoreComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Gore")
    TArray<FLITDBodyPartState> BodyParts;

    UPROPERTY(BlueprintAssignable)
    FLITDLimbSeveredEvent OnLimbSevered;

    UPROPERTY(BlueprintAssignable)
    FLITDLocalizedHitEvent OnLocalizedHit;

    UFUNCTION(BlueprintCallable, Category="Gore")
    bool ApplyLocalizedDamage(ELITDBodyZone Zone, float Damage, ELITDDamageNature Nature, FVector HitLocation, FVector Impulse);

    UFUNCTION(BlueprintPure, Category="Gore")
    bool IsSevered(ELITDBodyZone Zone) const;

private:
    FLITDBodyPartState* FindBodyPart(ELITDBodyZone Zone);
    const FLITDBodyPartState* FindBodyPart(ELITDBodyZone Zone) const;
    static bool DamageCanSever(ELITDDamageNature Nature);
};
