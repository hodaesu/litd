#include "Combat/LITDEquilibriumComponent.h"

ULITDEquilibriumComponent::ULITDEquilibriumComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
}

void ULITDEquilibriumComponent::BeginPlay()
{
    Super::BeginPlay();
    CurrentEquilibrium = MaxEquilibrium;
}

void ULITDEquilibriumComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
    TimeSinceDamage += DeltaTime;

    if (bBroken)
    {
        BrokenRemaining -= DeltaTime;
        if (BrokenRemaining <= 0.0f)
        {
            ResetEquilibrium();
        }
        return;
    }

    if (TimeSinceDamage >= RecoveryDelay && CurrentEquilibrium < MaxEquilibrium)
    {
        CurrentEquilibrium = FMath::Min(MaxEquilibrium, CurrentEquilibrium + RecoveryPerSecond * DeltaTime);
        OnEquilibriumChanged.Broadcast(CurrentEquilibrium);
    }
}

void ULITDEquilibriumComponent::ApplyEquilibriumDamage(const float Amount)
{
    if (Amount <= 0.0f || bBroken)
    {
        return;
    }
    TimeSinceDamage = 0.0f;
    CurrentEquilibrium = FMath::Max(0.0f, CurrentEquilibrium - Amount);
    OnEquilibriumChanged.Broadcast(CurrentEquilibrium);
    if (CurrentEquilibrium <= 0.0f)
    {
        bBroken = true;
        BrokenRemaining = BreakDuration;
        OnEquilibriumBroken.Broadcast();
    }
}

void ULITDEquilibriumComponent::ResetEquilibrium()
{
    bBroken = false;
    BrokenRemaining = 0.0f;
    TimeSinceDamage = 0.0f;
    CurrentEquilibrium = MaxEquilibrium;
    OnEquilibriumChanged.Broadcast(CurrentEquilibrium);
}
