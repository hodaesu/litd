#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "LITDCombatAnimationBridgeComponent.generated.h"

class ULITDCombatRuntimeComponent;
class ULITDCombatActionData;

/** One-way adapter: gameplay events drive animation. Animation never drives gameplay legality. */
UCLASS(ClassGroup=(LITD), meta=(BlueprintSpawnableComponent))
class LITDVALIDATION_API ULITDCombatAnimationBridgeComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Presentation")
    bool bStopMontageWhenGameplayActionEnds = false;

protected:
    virtual void BeginPlay() override;

private:
    UFUNCTION()
    void HandleActionStarted(ULITDCombatActionData* Action);

    UFUNCTION()
    void HandleActionEnded(ULITDCombatActionData* Action);
};
