#pragma once

#include "CoreMinimal.h"
#include "LITDCombatTypes.generated.h"

UENUM(BlueprintType)
enum class ELITDCombatActionPhase : uint8
{
    Idle,
    Startup,
    Active,
    Recovery
};

UENUM(BlueprintType)
enum class ELITDCombatInput : uint8
{
    None,
    Light,
    Heavy,
    Special,
    Dodge,
    Parry,
    Jump,
    Finisher
};

UENUM(BlueprintType)
enum class ELITDAttackThreatType : uint8
{
    Normal,
    Heavy,
    Thrust,
    Sweep,
    Grab,
    Supernatural
};

UENUM(BlueprintType)
enum class ELITDDefenseOutcome : uint8
{
    None,
    Block,
    PerfectParry,
    Dodge,
    PerfectDodge,
    Hit
};

UENUM(BlueprintType)
enum class ELITDBodyZone : uint8
{
    Head,
    Torso,
    ArmLeft,
    ArmRight,
    LegLeft,
    LegRight
};

UENUM(BlueprintType)
enum class ELITDDamageNature : uint8
{
    Slash,
    Blunt,
    Pierce,
    Light,
    Ash,
    Portal
};

USTRUCT(BlueprintType)
struct FLITDCombatWindow
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    FName Name = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, meta=(ClampMin="0.0"))
    float StartSeconds = 0.0f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, meta=(ClampMin="0.0"))
    float EndSeconds = 0.0f;

    bool Contains(const float TimeSeconds) const
    {
        return TimeSeconds >= StartSeconds && TimeSeconds <= EndSeconds;
    }
};

USTRUCT(BlueprintType)
struct FLITDCombatTransition
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    ELITDCombatInput Input = ELITDCombatInput::None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    FName RequiredWindow = NAME_None;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    FName NextActionId = NAME_None;
};

USTRUCT(BlueprintType)
struct FLITDHitProfile
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadOnly, meta=(ClampMin="0.0"))
    float HealthDamage = 10.0f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, meta=(ClampMin="0.0"))
    float EquilibriumDamage = 10.0f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly)
    ELITDDamageNature DamageNature = ELITDDamageNature::Slash;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, meta=(ClampMin="0.0"))
    float ImpactStrength = 1.0f;
};

USTRUCT(BlueprintType)
struct FLITDTargetingProfile
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadOnly, meta=(ClampMin="0.0"))
    float MaxRange = 500.0f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, meta=(ClampMin="0.0"))
    float DirectionWeight = 0.50f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, meta=(ClampMin="0.0"))
    float CameraWeight = 0.30f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, meta=(ClampMin="0.0"))
    float DistanceWeight = 0.20f;
};
