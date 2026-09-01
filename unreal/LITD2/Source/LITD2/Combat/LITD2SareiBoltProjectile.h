#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "LITD2SareiBoltProjectile.generated.h"

class UProjectileMovementComponent;
class USphereComponent;

UCLASS(Blueprintable)
class LITD2_API ALITD2SareiBoltProjectile : public AActor
{
    GENERATED_BODY()

public:
    ALITD2SareiBoltProjectile();

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="LITD2|Projectile")
    TObjectPtr<USphereComponent> Collision;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="LITD2|Projectile")
    TObjectPtr<UProjectileMovementComponent> ProjectileMovement;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Projectile|Combat")
    float Damage = 92.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Projectile|Combat")
    float Penetration = 0.58f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="LITD2|Projectile|Combat")
    float BleedValue = 0.32f;

    UFUNCTION(BlueprintCallable, Category="LITD2|Projectile")
    void InitializeBolt(float InDamage);

    UFUNCTION(BlueprintImplementableEvent, Category="LITD2|Projectile|Presentation")
    void OnBoltImpact(AActor* HitActor, bool bDamagedCombatant);

protected:
    virtual void BeginPlay() override;

private:
    UFUNCTION()
    void HandleHit(UPrimitiveComponent* HitComponent, AActor* OtherActor, UPrimitiveComponent* OtherComponent,
        FVector NormalImpulse, const FHitResult& Hit);
};
