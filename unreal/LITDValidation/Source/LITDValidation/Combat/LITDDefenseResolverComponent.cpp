#include "Combat/LITDDefenseResolverComponent.h"
#include "Combat/LITDCombatRuntimeComponent.h"

ELITDDefenseOutcome ULITDDefenseResolverComponent::ResolveThreat(const ELITDAttackThreatType Threat, const ULITDCombatRuntimeComponent* Runtime) const
{
    if (!Runtime)
    {
        return ELITDDefenseOutcome::Hit;
    }
    return ResolveThreatFromWindows(
        Threat,
        Runtime->IsWindowOpen(FName("Defense.Block")),
        Runtime->IsWindowOpen(FName("Defense.Perfect")),
        Runtime->IsWindowOpen(FName("Dodge.Invulnerable")),
        Runtime->IsWindowOpen(FName("Dodge.Perfect")),
        Runtime->IsWindowOpen(FName("Defense.Supernatural")));
}

ELITDDefenseOutcome ULITDDefenseResolverComponent::ResolveThreatFromWindows(const ELITDAttackThreatType Threat, const bool bBlock, const bool bPerfectParry, const bool bDodge, const bool bPerfectDodge, const bool bSupernaturalGuard) const
{
    if (bPerfectDodge)
    {
        return ELITDDefenseOutcome::PerfectDodge;
    }

    switch (Threat)
    {
    case ELITDAttackThreatType::Grab:
    case ELITDAttackThreatType::Sweep:
        return bDodge ? ELITDDefenseOutcome::Dodge : ELITDDefenseOutcome::Hit;

    case ELITDAttackThreatType::Supernatural:
        if (bSupernaturalGuard)
        {
            return ELITDDefenseOutcome::Block;
        }
        return bDodge ? ELITDDefenseOutcome::Dodge : ELITDDefenseOutcome::Hit;

    case ELITDAttackThreatType::Thrust:
    case ELITDAttackThreatType::Heavy:
        if (bPerfectParry)
        {
            return ELITDDefenseOutcome::PerfectParry;
        }
        if (bDodge)
        {
            return ELITDDefenseOutcome::Dodge;
        }
        return bBlock ? ELITDDefenseOutcome::Block : ELITDDefenseOutcome::Hit;

    case ELITDAttackThreatType::Normal:
    default:
        if (bPerfectParry)
        {
            return ELITDDefenseOutcome::PerfectParry;
        }
        if (bBlock)
        {
            return ELITDDefenseOutcome::Block;
        }
        return bDodge ? ELITDDefenseOutcome::Dodge : ELITDDefenseOutcome::Hit;
    }
}

float ULITDDefenseResolverComponent::GetBlockedEquilibriumMultiplier(const ELITDAttackThreatType Threat) const
{
    switch (Threat)
    {
    case ELITDAttackThreatType::Heavy: return 2.5f;
    case ELITDAttackThreatType::Thrust: return 1.75f;
    case ELITDAttackThreatType::Supernatural: return 2.0f;
    default: return 1.0f;
    }
}
