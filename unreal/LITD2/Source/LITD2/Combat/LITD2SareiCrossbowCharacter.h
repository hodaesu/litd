#pragma once

#include "CoreMinimal.h"
#include "Combat/LITD2CombatTypes.h"
#include "GameFramework/Character.h"
#include "LITD2SareiCrossbowCharacter.generated.h"

class ALITD2SareiBoltProjectile;
class UAnimMontage;
class ULITD2CombatantComponent;

UCLASS(Blueprintable)
class LITD2_API ALITD2SareiCrossbowCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ALITD2SareiCrossbowCharacter();

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="LITD2|Enemy")
    TObjectPtr<ULITD2CombatantComponent> Combatant;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float AggroRange = 1750.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float PreferredMinRange = 560.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float PreferredMaxRange = 1050.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float AimDurationSeconds = 0.82f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|AI")
    float ShotRecoverySeconds = 1.55f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Combat")
    float ShotDamage = 92.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Projectile")
    TSubclassOf<ALITD2SareiBoltProjectile> BoltClass;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> AimAndFireMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> HitReactionMontage;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Enemy|Animation")
    TObjectPtr<UAnimMontage> DeathMontage;

    // Called by ULITD2AnimNotify_CombatCommit at the exact bolt release frame.
    UFUNCTION(BlueprintCallable, Category="LITD2|Enemy|Animation")
    void ReleaseShotFromAnimation();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnShotTelegraphStarted();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnShotReleased();

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnDamagePresentation(FLITD2DamageResolution Resolution);

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Enemy|Presentation")
    void OnEnemyDeathPresentation();

protected:
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaSeconds) override;

private:
    float AimRemaining = 0.0f;
    float RecoveryRemaining = 0.0f;
    bool bShotQueued = false;
    bool bShotUsesAnimationCommit = false;

    void StartAiming();
    void ReleaseShot();
    void MoveRelativeToPlayer(const FVector& ToPlayer, float DirectionSign);
    void FacePlayer(const FVector& ToPlayer);

    UFUNCTION()
    void HandleDamageResolved(FLITD2DamageResolution Resolution);

    UFUNCTION()
    void HandleDeath();
};
