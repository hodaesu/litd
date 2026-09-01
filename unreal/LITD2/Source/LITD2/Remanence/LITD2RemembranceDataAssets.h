#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "LITD2RemembranceTypes.h"
#include "LITD2RemembranceDataAssets.generated.h"

class ULITD2RemembranceEntry;
class ULITD2RemembranceSource;

UCLASS(BlueprintType)
class LITD2_API ULITD2RemembranceSource : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    FName SourceId = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    ELITD2RemembranceSourceType SourceType = ELITD2RemembranceSourceType::EnvironmentalTrace;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    FText Title;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    FText Author;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    FText HistoricalDate;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    ELITD2ReliabilityClass Reliability = ELITD2ReliabilityClass::Uncertain;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence", meta=(MultiLine="true"))
    FText Text;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    TArray<FName> LinkedEntryIds;
};

UCLASS(BlueprintType)
class LITD2_API ULITD2RemembranceEntry : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    FName EntryId = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    FText Title;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    ELITD2RemembranceCategory Category = ELITD2RemembranceCategory::Unknown;

    // Authoring/default state. Player-specific runtime state is stored by the subsystem/save game.
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    ELITD2RemembranceDiscoveryState InitialState = ELITD2RemembranceDiscoveryState::Unknown;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence", meta=(MultiLine="true"))
    FText Description;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    FText Location;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    FText HistoricalDate;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    TArray<FName> RelatedCharacterIds;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    TArray<FName> RelatedFactionIds;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    TArray<FName> RelatedEntryIds;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    TArray<FName> SourceIds;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    TArray<FName> ContradictionEntryIds;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    ELITD2ReliabilityClass Reliability = ELITD2ReliabilityClass::Uncertain;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    TArray<FLITD2GameplayUnlock> GameplayUnlocks;
};

UCLASS(BlueprintType)
class LITD2_API ULITD2RemembranceReconstruction : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    FName ReconstructionId = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    FText Title;

    // Every entry in this list is mandatory.
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    TArray<FName> RequiredEntryIds;

    // Every group must be satisfied, but each group may offer several equivalent proofs.
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    TArray<FLITD2KnowledgeRequirementGroup> AlternativeRequirementGroups;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    FName ResultEntryId = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence")
    TArray<FLITD2GameplayUnlock> Unlocks;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Remanence", meta=(MultiLine="true"))
    FText ReconstructionExplanation;
};
