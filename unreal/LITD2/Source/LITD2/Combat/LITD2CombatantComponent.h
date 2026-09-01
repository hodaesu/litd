#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Combat/LITD2CombatTypes.h"
#include "LITD2CombatantComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FLITD2CombatFloatEvent, float, Value);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FLITD2DamageResolutionEvent, FLITD2DamageResolution, Resolution);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FLITD2CombatSimpleEvent);

UCLASS(ClassGroup=(LITD2), meta=(BlueprintSpawnableComponent))
class LITD2_API ULITD2CombatantComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    ULITD2CombatantComponent();

    UPROPERTY(BlueprintAssignable, Category="LITD2|Combat")
    FLITD2CombatFloatEvent OnHealthChanged;

    UPROPERTY(BlueprintAssignable, Category="LITD2|Combat")
    FLITD2CombatFloatEvent OnStaminaChanged;

    UPROPERTY(BlueprintAssignable, Category="LITD2|Combat")
    FLITD2DamageResolutionEvent OnDamageResolved;

    UPROPERTY(BlueprintAssignable, Category="LITD2|Combat")
    FLITD2CombatSimpleEvent OnDeath;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Vitals")
    float MaxHealth = 1000.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Vitals")
    float MaxStamina = 100.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Vitals")
    float StaminaRegenPerSecond = 24.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Defense")
    float ParryWindowSeconds = 0.18f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Defense")
    float BlockDamageMultiplier = 0.28f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Defense")
    float ParryDamageMultiplier = 0.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Run")
    bool bBridgeTraumaToRunDirector = false;

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat")
    void ResetCombatant();

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat")
    bool SpendStamina(float Amount);

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat|Defense")
    bool BeginParry();

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat|Defense")
    void EndParry();

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat|Defense")
    void SetBlocking(bool bNewBlocking);

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat|Defense")
    void StartInvulnerabilityWindow(float DurationSeconds);

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat|Wound")
    void ApplyTemporaryBleed(float DamagePerSecond, float DurationSeconds);

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat|Wound")
    void ClearTemporaryBleed();

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat|Healing")
    int32 RestoreRecoverableHealth();

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat|Healing")
    void ClearTraumaAndRestoreFull();

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat|Damage")
    FLITD2DamageResolution ReceiveDamageEvent(const FLITD2DamageEventPayload& Payload);

    UFUNCTION(BlueprintPure, Category="LITD2|Combat")
    float GetHealth() const { return Health; }

    UFUNCTION(BlueprintPure, Category="LITD2|Combat")
    float GetStamina() const { return Stamina; }

    UFUNCTION(BlueprintPure, Category="LITD2|Combat")
    float GetRecoverableMaxHealth() const { return FMath::Max(1.0f, MaxHealth - LockedHealth); }

    UFUNCTION(BlueprintPure, Category="LITD2|Combat")
    float GetLockedHealth() const { return LockedHealth; }

    UFUNCTION(BlueprintPure, Category="LITD2|Combat")
    int32 GetTraumaLevel() const { return TraumaLevel; }

    UFUNCTION(BlueprintPure, Category="LITD2|Combat|Wound")
    bool IsBleeding() const { return BleedTimeRemaining > 0.0f && ActiveBleedDamagePerSecond > 0.0f; }

    UFUNCTION(BlueprintPure, Category="LITD2|Combat|Wound")
    float GetBleedTimeRemaining() const { return BleedTimeRemaining; }

    UFUNCTION(BlueprintPure, Category="LITD2|Combat")
    bool IsDead() const { return Health <= 0.0f; }

    UFUNCTION(BlueprintPure, Category="LITD2|Combat|Defense")
    bool IsParryWindowActive() const { return ParryTimeRemaining > 0.0f; }

    UFUNCTION(BlueprintPure, Category="LITD2|Combat|Defense")
    bool IsInvulnerable() const { return InvulnerableTimeRemaining > 0.0f; }

protected:
    virtual void BeginPlay() override;
    virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

private:
    float Health = 1000.0f;
    float Stamina = 100.0f;
    float LockedHealth = 0.0f;
    int32 TraumaLevel = 0;
    float ParryTimeRemaining = 0.0f;
    float InvulnerableTimeRemaining = 0.0f;
    float ActiveBleedDamagePerSecond = 0.0f;
    float BleedTimeRemaining = 0.0f;
    float BleedRunBridgeAccumulator = 0.0f;
    bool bBlocking = false;
    bool bDeathBroadcast = false;

    void TickTemporaryBleed(float DeltaTime);
    void BridgeCombatDamageToRun(int32 DamageAmount);
    void BroadcastDeathIfNeeded();
    ELITD2BodyZone ResolveBodyZone(FName HitBone) const;
    FLITD2DamageResolution ResolvePipeline(FLITD2DamageEventPayload Payload);
};
