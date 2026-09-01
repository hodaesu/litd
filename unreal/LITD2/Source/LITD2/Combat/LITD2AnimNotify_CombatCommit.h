#pragma once

#include "CoreMinimal.h"
#include "Animation/AnimNotifies/AnimNotify.h"
#include "LITD2AnimNotify_CombatCommit.generated.h"

UENUM(BlueprintType)
enum class ELITD2CombatCommitEvent : uint8
{
    PlayerQueuedAttack,
    AshWandererAttack,
    LineBreakerSevereAttack,
    SareiCrossbowRelease
};

UCLASS(meta=(DisplayName="LITD2 Combat Commit"))
class LITD2_API ULITD2AnimNotify_CombatCommit : public UAnimNotify
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat")
    ELITD2CombatCommitEvent CommitEvent = ELITD2CombatCommitEvent::PlayerQueuedAttack;

    virtual void Notify(USkeletalMeshComponent* MeshComp, UAnimSequenceBase* Animation,
        const FAnimNotifyEventReference& EventReference) override;

    virtual FString GetNotifyName_Implementation() const override;
};
