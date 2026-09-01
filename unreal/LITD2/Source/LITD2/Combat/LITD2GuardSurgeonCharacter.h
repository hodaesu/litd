#pragma once

#include "CoreMinimal.h"
#include "Combat/LITD2CombatTypes.h"
#include "GameFramework/Character.h"
#include "LITD2GuardSurgeonCharacter.generated.h"

class UAnimMontage;
class ULITD2CombatantComponent;

enum class ELITD2GuardSurgeonAction : uint8
{
    None,
    Incision,
    Grab,
    SevereStrike
};

UCLASS(Blueprintable)
class LITD2_API ALITD2GuardSurgeonCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ALITD2GuardSurgeonCharacter();

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="LITD2|Enemy")
    TObjectPtr<ULITD2CombatantComponent> Combatant;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float AggroRange = 1400.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float EngageRange = 235.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Interrupt")
    float InterruptWindowSeconds = 0.58f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Interrupt")
    float InterruptDamageThreshold = 115.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Interrupt")
    float InterruptedRecoverySeconds = 1.75f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Incision")
    float IncisionDamage = 76.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Incision")
    float IncisionWindupSeconds = 0.46f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Incision")
    float IncisionRecoverySeconds = 0.68f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Grab")
    float GrabDamage = 58.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Grab")
    float GrabWindupSeconds = 0.82f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Grab")
    float GrabRecoverySeconds = 1.05f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Grab")
    float GrabLockSeconds = 0.45f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Severe")
    float SevereDamage = 155.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Severe")
    float SevereWindupSeconds = 1.25f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Severe")
    float SevereRecoverySeconds = 1.60f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> IncisionMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> GrabMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> SevereStrikeMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> HitReactionMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> InterruptedMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> DeathMontage;

    UFUNCTION(BlueprintCallable, Category="LITD2|Enemy|Animation")
    void CommitIncisionFromAnimation();

    UFUNCTION(BlueprintCallable, Category="LITD2|Enemy|Animation")
    void CommitGrabFromAnimation();

    UFUNCTION(BlueprintCallable, Category="LITD2|Enemy|Animation")
    void CommitSevereStrikeFromAnimation();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnActionTelegraphStarted(FName ActionId);

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnActionCommitted(FName ActionId);

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnInterruptedPresentation(FName ActionId);

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnParriedPresentation(FName ActionId);

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnDamagePresentation(FLITD2DamageResolution Resolution);

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnEnemyDeathPresentation();

protected:
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaSeconds) override;

private:
    ELITD2GuardSurgeonAction CurrentAction = ELITD2GuardSurgeonAction::None;
    float WindupRemaining = 0.0f;
    float RecoveryRemaining = 0.0f;
    float InterruptWindowRemaining = 0.0f;
    float InterruptDamageAccumulated = 0.0f;
    bool bActionUsesAnimationCommit = false;
    int32 ActionCycleIndex = 0;

    void StartNextAction();
    void QueueAction(ELITD2GuardSurgeonAction Action);
    void CommitCurrentAction();
    void CommitIncision();
    void CommitGrab();
    void CommitSevereStrike();
    void InterruptCurrentAction();
    void ClearCurrentAction();
    float GetWindupForAction(ELITD2GuardSurgeonAction Action) const;
    float GetRecoveryForAction(ELITD2GuardSurgeonAction Action) const;
    UAnimMontage* GetMontageForAction(ELITD2GuardSurgeonAction Action) const;
    FName GetActionId(ELITD2GuardSurgeonAction Action) const;

    UFUNCTION()
    void HandleDamageResolved(FLITD2DamageResolution Resolution);

    UFUNCTION()
    void HandleDeath();
};
