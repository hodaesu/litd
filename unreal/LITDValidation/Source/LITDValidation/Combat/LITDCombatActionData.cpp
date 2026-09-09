#include "Combat/LITDCombatActionData.h"

float ULITDCombatActionData::GetTotalDuration() const
{
    return FMath::Max(0.0f, StartupSeconds) + FMath::Max(0.0f, ActiveSeconds) + FMath::Max(0.0f, RecoverySeconds);
}

ELITDCombatActionPhase ULITDCombatActionData::GetPhaseAtTime(const float TimeSeconds) const
{
    if (TimeSeconds < 0.0f || TimeSeconds >= GetTotalDuration())
    {
        return ELITDCombatActionPhase::Idle;
    }
    if (TimeSeconds < StartupSeconds)
    {
        return ELITDCombatActionPhase::Startup;
    }
    if (TimeSeconds < StartupSeconds + ActiveSeconds)
    {
        return ELITDCombatActionPhase::Active;
    }
    return ELITDCombatActionPhase::Recovery;
}

bool ULITDCombatActionData::IsWindowOpen(const FName WindowName, const float TimeSeconds) const
{
    for (const FLITDCombatWindow& Window : Windows)
    {
        if (Window.Name == WindowName && Window.Contains(TimeSeconds))
        {
            return true;
        }
    }
    return false;
}

const FLITDCombatTransition* ULITDCombatActionData::FindTransition(const ELITDCombatInput RequestedInput, const float TimeSeconds) const
{
    for (const FLITDCombatTransition& Transition : Transitions)
    {
        if (Transition.Input != RequestedInput)
        {
            continue;
        }
        if (Transition.RequiredWindow.IsNone() || IsWindowOpen(Transition.RequiredWindow, TimeSeconds))
        {
            return &Transition;
        }
    }
    return nullptr;
}
