#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Combat/LITDCombatTypes.h"
#include "LITDTargetingComponent.generated.h"

UCLASS(ClassGroup=(LITD), meta=(BlueprintSpawnableComponent))
class LITDVALIDATION_API ULITDTargetingComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Targeting")
    FLITDTargetingProfile DefaultProfile;

    UFUNCTION(BlueprintCallable, Category="Targeting")
    AActor* ChooseSoftTarget(const TArray<AActor*>& Candidates, FVector DesiredDirection, FVector CameraForward, const FLITDTargetingProfile& Profile) const;

    UFUNCTION(BlueprintCallable, Category="Targeting")
    void SetLockedTarget(AActor* Target) { LockedTarget = Target; }

    UFUNCTION(BlueprintCallable, Category="Targeting")
    void ClearLockedTarget() { LockedTarget.Reset(); }

    UFUNCTION(BlueprintPure, Category="Targeting")
    AActor* GetLockedTarget() const { return LockedTarget.Get(); }

private:
    TWeakObjectPtr<AActor> LockedTarget;
};
