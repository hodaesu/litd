#include "Run/LITD2RunInteractionActors.h"

#include "Engine/GameInstance.h"
#include "Run/LITD2RunDirectorSubsystem.h"

namespace
{
    ULITD2RunDirectorSubsystem* GetRunDirector(const AActor* Actor)
    {
        if (!Actor || !Actor->GetGameInstance())
        {
            return nullptr;
        }
        return Actor->GetGameInstance()->GetSubsystem<ULITD2RunDirectorSubsystem>();
    }
}

int32 ALITD2HealingPoint::UseHealingPoint()
{
    if (ULITD2RunDirectorSubsystem* Director = GetRunDirector(this))
    {
        return Director->UseFountain();
    }
    return 0;
}

bool ALITD2MedicalCache::TryTakeReplacementPotion()
{
    if (bConsumed)
    {
        return false;
    }

    if (ULITD2RunDirectorSubsystem* Director = GetRunDirector(this))
    {
        if (Director->GrantContextualReplacementPotion())
        {
            bConsumed = true;
            return true;
        }
    }
    return false;
}

bool ALITD2RemanenceTrigger::TriggerRemanence()
{
    if (bTriggered || RemanenceEntryId.IsNone())
    {
        return false;
    }

    if (ULITD2RunDirectorSubsystem* Director = GetRunDirector(this))
    {
        if (Director->DiscoverRemanence(RemanenceEntryId))
        {
            bTriggered = true;
            return true;
        }
    }
    return false;
}

bool ALITD2BranchGate::ChooseThisBranch()
{
    if (BranchId.IsNone())
    {
        return false;
    }

    if (ULITD2RunDirectorSubsystem* Director = GetRunDirector(this))
    {
        return Director->ChooseBranch(BranchId);
    }
    return false;
}
