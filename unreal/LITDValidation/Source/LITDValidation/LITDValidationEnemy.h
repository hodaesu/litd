#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "LITDValidationEnemy.generated.h"

UCLASS()
class LITDVALIDATION_API ALITDValidationEnemy : public AActor
{
    GENERATED_BODY()

public:
    ALITDValidationEnemy();
    void Configure(int32 Index);
    void ReceiveTestDamage(float Amount);
    bool IsCapturable() const;
    float HealthRatio() const;

private:
    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> Visual;

    UPROPERTY()
    TObjectPtr<UMaterialInstanceDynamic> Material;

    float Health = 100.0f;
    float MaxHealth = 100.0f;
    bool bDefeated = false;

    void RefreshColor();
};
