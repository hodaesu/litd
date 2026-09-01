#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "LITD2AshWandererCharacter.generated.h"

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

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnAttackTelegraphStarted();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnAttackCommitted();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnEnemyDeathPresentation();

protected:
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaSeconds) override;

private:
    float WindupRemaining = 0.0f;
    float RecoveryRemaining = 0.0f;
    bool bAttackQueued = false;

    void StartAttack();
    void CommitAttack();

    UFUNCTION()
    void HandleDeath();
};
