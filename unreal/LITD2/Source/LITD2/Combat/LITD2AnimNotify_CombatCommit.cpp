#include "Combat/LITD2AnimNotify_CombatCommit.h"

#include "Combat/LITD2AlleyHarrierCharacter.h"
#include "Combat/LITD2AshWandererCharacter.h"
#include "Combat/LITD2LineBreakerCharacter.h"
#include "Combat/LITD2PlayerCombatCharacter.h"
#include "Combat/LITD2SareiCrossbowCharacter.h"
#include "Components/SkeletalMeshComponent.h"

void ULITD2AnimNotify_CombatCommit::Notify(USkeletalMeshComponent* MeshComp, UAnimSequenceBase* Animation,
    const FAnimNotifyEventReference& EventReference)
{
    Super::Notify(MeshComp, Animation, EventReference);
    if (!MeshComp) return;

    AActor* Owner = MeshComp->GetOwner();
    if (!Owner) return;

    switch (CommitEvent)
    {
        case ELITD2CombatCommitEvent::PlayerQueuedAttack:
            if (ALITD2PlayerCombatCharacter* Player = Cast<ALITD2PlayerCombatCharacter>(Owner))
            {
                Player->CommitQueuedAttackFromAnimation();
            }
            break;

        case ELITD2CombatCommitEvent::AshWandererAttack:
            if (ALITD2AshWandererCharacter* Wanderer = Cast<ALITD2AshWandererCharacter>(Owner))
            {
                Wanderer->CommitAttackFromAnimation();
            }
            break;

        case ELITD2CombatCommitEvent::LineBreakerSevereAttack:
            if (ALITD2LineBreakerCharacter* Breaker = Cast<ALITD2LineBreakerCharacter>(Owner))
            {
                Breaker->CommitSevereAttackFromAnimation();
            }
            break;

        case ELITD2CombatCommitEvent::SareiCrossbowRelease:
            if (ALITD2SareiCrossbowCharacter* Crossbow = Cast<ALITD2SareiCrossbowCharacter>(Owner))
            {
                Crossbow->ReleaseShotFromAnimation();
            }
            break;

        case ELITD2CombatCommitEvent::AlleyHarrierLunge:
            if (ALITD2AlleyHarrierCharacter* Harrier = Cast<ALITD2AlleyHarrierCharacter>(Owner))
            {
                Harrier->CommitLungeFromAnimation();
            }
            break;
    }
}

FString ULITD2AnimNotify_CombatCommit::GetNotifyName_Implementation() const
{
    switch (CommitEvent)
    {
        case ELITD2CombatCommitEvent::PlayerQueuedAttack: return TEXT("LITD2 Player Hit");
        case ELITD2CombatCommitEvent::AshWandererAttack: return TEXT("LITD2 Ash Wanderer Hit");
        case ELITD2CombatCommitEvent::LineBreakerSevereAttack: return TEXT("LITD2 Line Breaker Impact");
        case ELITD2CombatCommitEvent::SareiCrossbowRelease: return TEXT("LITD2 Crossbow Release");
        case ELITD2CombatCommitEvent::AlleyHarrierLunge: return TEXT("LITD2 Alley Harrier Lunge");
    }
    return TEXT("LITD2 Combat Commit");
}
