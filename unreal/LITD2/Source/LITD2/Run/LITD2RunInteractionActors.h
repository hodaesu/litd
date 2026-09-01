#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "LITD2RunInteractionActors.generated.h"

UCLASS(Blueprintable)
class LITD2_API ALITD2HealingPoint : public AActor
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintCallable, Category="LITD2|Run|Interaction")
    int32 UseHealingPoint();
};

UCLASS(Blueprintable)
class LITD2_API ALITD2MedicalCache : public AActor
{
    GENERATED_BODY()

public:
    UPROPERTY(BlueprintReadOnly, Category="LITD2|Run|Interaction")
    bool bConsumed = false;

    UFUNCTION(BlueprintCallable, Category="LITD2|Run|Interaction")
    bool TryTakeReplacementPotion();
};

UCLASS(Blueprintable)
class LITD2_API ALITD2RemanenceTrigger : public AActor
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="LITD2|Run|Interaction")
    FName RemanenceEntryId = NAME_None;

    UPROPERTY(BlueprintReadOnly, Category="LITD2|Run|Interaction")
    bool bTriggered = false;

    UFUNCTION(BlueprintCallable, Category="LITD2|Run|Interaction")
    bool TriggerRemanence();
};

UCLASS(Blueprintable)
class LITD2_API ALITD2BranchGate : public AActor
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="LITD2|Run|Interaction")
    FName BranchId = NAME_None;

    UFUNCTION(BlueprintCallable, Category="LITD2|Run|Interaction")
    bool ChooseThisBranch();
};
