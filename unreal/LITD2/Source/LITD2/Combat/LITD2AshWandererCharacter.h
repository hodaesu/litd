#pragma once

#include "CoreMinimal.h"
#include "Combat/LITD2CombatTypes.h"
#include "GameFramework/Character.h"
#include "LITD2AshWandererCharacter.generated.h"

class UAnimMontage;
class ULITD2CombatantComponent;

UCLASS(Blueprintable)
class LITD2_API ALITD2AshWandererCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ALITD2AshWandererCharacter();

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="LITD2|Enemy")
    TObjectPtr<ULITD2CombatantComponent> Combatant;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float AggroRange = 1250.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float AttackRange = 165.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float AttackWindupSeconds = 0.48f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float AttackRecoverySeconds = 0.78f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Combat")
    float AttackDamage = 74.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> AttackMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> HitReactionMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> DeathMontage;

    // Called by ULITD2AnimNotify_CombatCommit on the exact contact frame.
    UFUNCTION(BlueprintCallable, Category="LITD2|Enemy|Animation")
    void CommitAttackFromAnimation();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnAttackTelegraphStarted();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnAttackCommitted();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnParriedPresentation();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnDamagePresentation(FLITD2DamageResolution Resolution);

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnEnemyDeathPresentation();

protected:
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaSeconds) override;

private:
    float WindupRemaining = 0.0f;
    float RecoveryRemaining = 0.0f;
    bool bAttackQueued = false;
    bool bAttackUsesAnimationCommit = false;

    void StartAttack();
    void CommitAttack();

    UFUNCTION()
    void HandleDamageResolved(FLITD2DamageResolution Resolution);

    UFUNCTION()
    void HandleDeath();
};
