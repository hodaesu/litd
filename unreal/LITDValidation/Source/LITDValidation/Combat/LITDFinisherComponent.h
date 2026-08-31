#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Engine/DataAsset.h"
#include "LITDFinisherComponent.generated.h"

class UAnimMontage;

UCLASS(BlueprintType)
class LITDVALIDATION_API ULITDFinisherData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    FName FinisherId = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, meta=(ClampMin="0.0", ClampMax="1.0"))
    float MaxTargetHealthRatio = 0.25f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    bool bRequiresBrokenEquilibrium = true;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, meta=(ClampMin="0.0"))
    float MaxDistance = 180.0f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    TArray<FName> RequiredContextTags;

    /** Presentation-only. Eligibility does not inspect animation state or montage position. */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Presentation")
    TSoftObjectPtr<UAnimMontage> PresentationMontage;
};

UCLASS(ClassGroup=(LITD), meta=(BlueprintSpawnableComponent))
class LITDVALIDATION_API ULITDFinisherComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Finishers")
    TArray<TObjectPtr<ULITDFinisherData>> Finishers;

    UFUNCTION(BlueprintPure, Category="Finishers")
    bool IsEligible(const ULITDFinisherData* Finisher, float TargetHealthRatio, bool bTargetEquilibriumBroken, float Distance, const TArray<FName>& ContextTags) const;

    UFUNCTION(BlueprintCallable, Category="Finishers")
    ULITDFinisherData* FindEligibleFinisher(float TargetHealthRatio, bool bTargetEquilibriumBroken, float Distance, const TArray<FName>& ContextTags) const;
};
