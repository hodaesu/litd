#pragma once

#include "CoreMinimal.h"
#include "Combat/LITD2CombatTypes.h"
#include "GameFramework/Character.h"
#include "LITD2LineBreakerCharacter.generated.h"

class UAnimMontage;
class ULITD2CombatantComponent;

UCLASS(Blueprintable)
class LITD2_API ALITD2LineBreakerCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ALITD2LineBreakerCharacter();

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="LITD2|Enemy")
    TObjectPtr<ULITD2CombatantComponent> Combatant;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float AggroRange = 1250.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float SevereAttackRange = 195.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float SevereWindupSeconds = 1.10f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float SevereRecoverySeconds = 1.55f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Combat")
    float SevereAttackDamage = 145.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> SevereAttackMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> HitReactionMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> DeathMontage;

    // Called by ULITD2AnimNotify_CombatCommit at the exact impact frame.
    UFUNCTION(BlueprintCallable, Category="LITD2|Enemy|Animation")
    void CommitSevereAttackFromAnimation();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnSevereTelegraphStarted();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnSevereAttackCommitted();

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
    bool bSevereAttackQueued = false;
    bool bAttackUsesAnimationCommit = false;

    void StartSevereAttack();
    void CommitSevereAttack();

    UFUNCTION()
    void HandleDamageResolved(FLITD2DamageResolution Resolution);

    UFUNCTION()
    void HandleDeath();
};
