#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "Combat/LITD2CombatTypes.h"
#include "LITD2PlayerCombatCharacter.generated.h"

class UCameraComponent;
class USpringArmComponent;
class ULITD2CombatantComponent;

UCLASS(Blueprintable)
class LITD2_API ALITD2PlayerCombatCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ALITD2PlayerCombatCharacter();

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="LITD2|Combat")
    TObjectPtr<ULITD2CombatantComponent> Combatant;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="LITD2|Camera")
    TObjectPtr<USpringArmComponent> CameraBoom;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="LITD2|Camera")
    TObjectPtr<UCameraComponent> FollowCamera;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Attack")
    float LightAttackDamage = 85.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Attack")
    float HeavyAttackDamage = 175.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Attack")
    float AttackReach = 220.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Attack")
    float AttackRadius = 54.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Dodge")
    float DodgeStrength = 680.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Combat|Dodge")
    float DodgeInvulnerabilitySeconds = 0.22f;

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat")
    bool LightAttack();

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat")
    bool HeavyAttack();

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat")
    bool Dodge();

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat")
    bool BeginParry();

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat")
    void EndParry();

    UFUNCTION(BlueprintCallable, Category="LITD2|Combat|Healing")
    bool UsePotion();

protected:
    virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;

private:
    void MoveForward(float Value);
    void MoveRight(float Value);
    void Turn(float Value);
    void LookUp(float Value);
    void StartBlock();
    void StopBlock();
    bool PerformMeleeTrace(ELITD2AttackKind AttackKind);
};
