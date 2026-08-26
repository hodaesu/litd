#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "LITDValidationStation.generated.h"

UENUM()
enum class ELITDValidationStationType : uint8
{
    Dialogue,
    LootChest,
    AshGuidance,
    Psychology,
    PersistentInjury,
    SaveRoundtrip
};

UCLASS()
class LITDVALIDATION_API ALITDValidationStation : public AActor
{
    GENERATED_BODY()

public:
    ALITDValidationStation();
    void Configure(ELITDValidationStationType InType, const FString& InLabel, const FLinearColor& InColor);
    void Interact(APawn* InstigatorPawn);
    FString Prompt() const;

private:
    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> Visual;

    ELITDValidationStationType Type = ELITDValidationStationType::Dialogue;
    FString Label;
    bool bConsumed = false;
};
