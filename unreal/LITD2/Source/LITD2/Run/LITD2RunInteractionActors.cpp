#include "Run/LITD2RunInteractionActors.h"

#include "Combat/LITD2CombatantComponent.h"
#include "Engine/GameInstance.h"
#include "GameFramework/Character.h"
#include "Kismet/GameplayStatics.h"
#include "Run/LITD2RunDirectorSubsystem.h"

namespace
{
    ULITD2RunDirectorSubsystem* GetRunDirector(AActor* Actor)
    {
        if (!Actor || !Actor->GetGameInstance()) return nullptr;
        return Actor->GetGameInstance()->GetSubsystem<ULITD2RunDirectorSubsystem>();
    }

    ULITD2CombatantComponent* GetPlayerCombatant(AActor* Actor)
    {
        if (!Actor) return nullptr;
        if (ACharacter* Player = UGameplayStatics::GetPlayerCharacter(Actor, 0))
        {
            return Player->FindComponentByClass<ULITD2CombatantComponent>();
        }
        return nullptr;
    }
}

int32 ALITD2HealingPoint::UseHealingPoint()
{
    ULITD2RunDirectorSubsystem* Director = GetRunDirector(this);
    ULITD2CombatantComponent* Combatant = GetPlayerCombatant(this);
    if (!Director || !Combatant) return 0;

    const int32 RuntimeHealed = Director->UseFountain();
    const int32 CombatHealed = Combatant->RestoreRecoverableHealth();
    return FMath::Min(RuntimeHealed, CombatHealed);
}

bool ALITD2MedicalCache::TryTakeReplacementPotion()
{
    if (bConsumed) return false;

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
    if (bTriggered || RemanenceEntryId.IsNone()) return false;

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
    if (BranchId.IsNone()) return false;

    if (ULITD2RunDirectorSubsystem* Director = GetRunDirector(this))
    {
        return Director->ChooseBranch(BranchId);
    }
    return false;
}
