#include "Combat/LITDFinisherComponent.h"

bool ULITDFinisherComponent::IsEligible(const ULITDFinisherData* Finisher, const float TargetHealthRatio, const bool bTargetEquilibriumBroken, const float Distance, const TArray<FName>& ContextTags) const
{
    if (!Finisher || TargetHealthRatio > Finisher->MaxTargetHealthRatio || Distance > Finisher->MaxDistance)
    {
        return false;
    }
    if (Finisher->bRequiresBrokenEquilibrium && !bTargetEquilibriumBroken)
    {
        return false;
    }
    for (const FName RequiredTag : Finisher->RequiredContextTags)
    {
        if (!ContextTags.Contains(RequiredTag))
        {
            return false;
        }
    }
    return true;
}

ULITDFinisherData* ULITDFinisherComponent::FindEligibleFinisher(const float TargetHealthRatio, const bool bTargetEquilibriumBroken, const float Distance, const TArray<FName>& ContextTags) const
{
    for (ULITDFinisherData* Finisher : Finishers)
    {
        if (IsEligible(Finisher, TargetHealthRatio, bTargetEquilibriumBroken, Distance, ContextTags))
        {
            return Finisher;
        }
    }
    return nullptr;
}
