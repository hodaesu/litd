#pragma once

#include "CoreMinimal.h"
#include "LITD2RemembranceTypes.generated.h"

UENUM(BlueprintType)
enum class ELITD2RemembranceCategory : uint8
{
    Unknown,
    Body,
    Mind,
    Politics,
    Battle,
    Person,
    City,
    Place,
    Medicine,
    Technology,
    War,
    Object,
    Faction
};

UENUM(BlueprintType)
enum class ELITD2RemembranceDiscoveryState : uint8
{
    Unknown,
    Trace,
    Documented,
    Reconstructed,
    Contested
};

UENUM(BlueprintType)
enum class ELITD2ReliabilityClass : uint8
{
    Confirmed,
    Probable,
    Uncertain,
    Contested,
    SingleTestimony,
    ProbablePropaganda
};

UENUM(BlueprintType)
enum class ELITD2RemembranceSourceType : uint8
{
    Echo,
    Testimony,
    MedicalReport,
    MilitaryReport,
    PoliticalArchive,
    ObjectAnalysis,
    EnvironmentalTrace,
    MajorRemanence
};

UENUM(BlueprintType)
enum class ELITD2UnlockType : uint8
{
    None,
    GameplayFeature,
    Battle,
    Lore,
    Equipment,
    SkillVariant,
    Oath,
    Preparation,
    EnemyKnowledge,
    LogisticsCapacity
};

USTRUCT(BlueprintType)
struct FLITD2GameplayUnlock
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    FName UnlockId = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    ELITD2UnlockType Type = ELITD2UnlockType::None;

    // Optional whole-number payload, e.g. PotionCapacity = 4.
    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    int32 IntegerValue = 0;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    float NumericValue = 0.0f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    FText Explanation;
};

USTRUCT(BlueprintType)
struct FLITD2KnowledgeRequirementGroup
{
    GENERATED_BODY()

    // At least MinimumMatches entries/sources across these two lists must be known.
    // This supports alternate evidence paths and prevents single-missed-item hard locks.
    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    TArray<FName> AnyOfEntryIds;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    TArray<FName> AnyOfSourceIds;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, meta=(ClampMin="1"))
    int32 MinimumMatches = 1;
};
