#pragma once

#include "CoreMinimal.h"
#include "Combat/LITD2CombatTypes.h"
#include "GameFramework/Character.h"
#include "LITD2AlleyHarrierCharacter.generated.h"

class UAnimMontage;
class ULITD2CombatantComponent;

UCLASS(Blueprintable)
class LITD2_API ALITD2AlleyHarrierCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ALITD2AlleyHarrierCharacter();

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="LITD2|Enemy")
    TObjectPtr<ULITD2CombatantComponent> Combatant;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float AggroRange = 1450.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float PreferredOrbitRange = 360.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float LungeRange = 430.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float LungeWindupSeconds = 0.34f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float RecoverySeconds = 0.72f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Combat")
    float LungeDamage = 62.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Combat")
    float LungeStrength = 980.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> LungeMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> HitReactionMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> DeathMontage;

    UFUNCTION(BlueprintCallable, Category="LITD2|Enemy|Combat")
    void CommitLungeFromAnimation();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnLungeTelegraphStarted();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnLungeCommitted();

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
    bool bLungeQueued = false;
    bool bLungeUsesAnimationCommit = false;
    int32 OrbitDirectionSign = 1;

    void StartLunge();
    void CommitLunge();
    void OrbitPlayer(const FVector& ToPlayer);

    UFUNCTION()
    void HandleDamageResolved(FLITD2DamageResolution Resolution);

    UFUNCTION()
    void HandleDeath();
};
