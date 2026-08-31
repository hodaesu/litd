#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "LITDEquilibriumComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FLITDEquilibriumBrokenEvent);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FLITDEquilibriumChangedEvent, float, CurrentValue);

UCLASS(ClassGroup=(LITD), meta=(BlueprintSpawnableComponent))
class LITDVALIDATION_API ULITDEquilibriumComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    ULITDEquilibriumComponent();

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Equilibrium", meta=(ClampMin="1.0"))
    float MaxEquilibrium = 100.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Equilibrium", meta=(ClampMin="0.0"))
    float RecoveryPerSecond = 12.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Equilibrium", meta=(ClampMin="0.0"))
    float RecoveryDelay = 1.25f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Equilibrium", meta=(ClampMin="0.0"))
    float BreakDuration = 1.0f;

    UPROPERTY(BlueprintAssignable)
    FLITDEquilibriumBrokenEvent OnEquilibriumBroken;

    UPROPERTY(BlueprintAssignable)
    FLITDEquilibriumChangedEvent OnEquilibriumChanged;

    UFUNCTION(BlueprintCallable)
    void ApplyEquilibriumDamage(float Amount);

    UFUNCTION(BlueprintCallable)
    void ResetEquilibrium();

    UFUNCTION(BlueprintPure)
    bool IsBroken() const { return bBroken; }

    UFUNCTION(BlueprintPure)
    float GetCurrentEquilibrium() const { return CurrentEquilibrium; }

protected:
    virtual void BeginPlay() override;
    virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

private:
    float CurrentEquilibrium = 100.0f;
    float TimeSinceDamage = 0.0f;
    float BrokenRemaining = 0.0f;
    bool bBroken = false;
};
