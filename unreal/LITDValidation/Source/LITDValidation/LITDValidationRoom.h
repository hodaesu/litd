#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "LITDValidationRoom.generated.h"

class UStaticMeshComponent;

UCLASS()
class LITDVALIDATION_API ALITDValidationRoom : public AActor
{
    GENERATED_BODY()

public:
    ALITDValidationRoom();
    virtual void OnConstruction(const FTransform& Transform) override;

private:
    UPROPERTY()
    TArray<TObjectPtr<UStaticMeshComponent>> Geometry;

    void Rebuild();
    UStaticMeshComponent* AddBlock(const FName Name, const FVector& Location, const FVector& Scale, const FLinearColor& Color);
};
