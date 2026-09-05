#include "Combat/LITDCombatAnimationBridgeComponent.h"
#include "Combat/LITDCombatRuntimeComponent.h"
#include "Combat/LITDCombatActionData.h"
#include "Animation/AnimInstance.h"
#include "Animation/AnimMontage.h"
#include "GameFramework/Character.h"

void ULITDCombatAnimationBridgeComponent::BeginPlay()
{
    Super::BeginPlay();
    if (ULITDCombatRuntimeComponent* Runtime = GetOwner()->FindComponentByClass<ULITDCombatRuntimeComponent>())
    {
        Runtime->OnActionStarted.AddDynamic(this, &ULITDCombatAnimationBridgeComponent::HandleActionStarted);
        Runtime->OnActionEnded.AddDynamic(this, &ULITDCombatAnimationBridgeComponent::HandleActionEnded);
    }
}

void ULITDCombatAnimationBridgeComponent::HandleActionStarted(ULITDCombatActionData* Action)
{
    ACharacter* Character = Cast<ACharacter>(GetOwner());
    UAnimInstance* AnimInstance = Character && Character->GetMesh() ? Character->GetMesh()->GetAnimInstance() : nullptr;
    UAnimMontage* Montage = Action ? Action->PresentationMontage.Get() : nullptr;
    if (AnimInstance && Montage)
    {
        AnimInstance->Montage_Play(Montage, Action->PresentationPlayRate);
    }
}

void ULITDCombatAnimationBridgeComponent::HandleActionEnded(ULITDCombatActionData* Action)
{
    if (!bStopMontageWhenGameplayActionEnds)
    {
        return;
    }
    ACharacter* Character = Cast<ACharacter>(GetOwner());
    UAnimInstance* AnimInstance = Character && Character->GetMesh() ? Character->GetMesh()->GetAnimInstance() : nullptr;
    UAnimMontage* Montage = Action ? Action->PresentationMontage.Get() : nullptr;
    if (AnimInstance && Montage && AnimInstance->Montage_IsPlaying(Montage))
    {
        AnimInstance->Montage_Stop(0.08f, Montage);
    }
}
