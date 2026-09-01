#include "Combat/LITD2SareiBoltProjectile.h"

#include "Combat/LITD2CombatantComponent.h"
#include "Components/SphereComponent.h"
#include "GameFramework/ProjectileMovementComponent.h"

ALITD2SareiBoltProjectile::ALITD2SareiBoltProjectile()
{
    PrimaryActorTick.bCanEverTick = false;

    Collision = CreateDefaultSubobject<USphereComponent>(TEXT("Collision"));
    SetRootComponent(Collision);
    Collision->InitSphereRadius(7.0f);
    Collision->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    Collision->SetCollisionObjectType(ECC_WorldDynamic);
    Collision->SetCollisionResponseToAllChannels(ECR_Ignore);
    Collision->SetCollisionResponseToChannel(ECC_Pawn, ECR_Block);
    Collision->SetCollisionResponseToChannel(ECC_WorldStatic, ECR_Block);
    Collision->SetCollisionResponseToChannel(ECC_WorldDynamic, ECR_Block);
    Collision->OnComponentHit.AddDynamic(this, &ALITD2SareiBoltProjectile::HandleHit);

    ProjectileMovement = CreateDefaultSubobject<UProjectileMovementComponent>(TEXT("ProjectileMovement"));
    ProjectileMovement->UpdatedComponent = Collision;
    ProjectileMovement->InitialSpeed = 3200.0f;
    ProjectileMovement->MaxSpeed = 3200.0f;
    ProjectileMovement->bRotationFollowsVelocity = true;
    ProjectileMovement->bShouldBounce = false;
    ProjectileMovement->ProjectileGravityScale = 0.12f;

    InitialLifeSpan = 4.5f;
}

void ALITD2SareiBoltProjectile::BeginPlay()
{
    Super::BeginPlay();
    if (AActor* BoltOwner = GetOwner())
    {
        Collision->IgnoreActorWhenMoving(BoltOwner, true);
    }
}

void ALITD2SareiBoltProjectile::InitializeBolt(float InDamage)
{
    Damage = FMath::Max(0.0f, InDamage);
}

void ALITD2SareiBoltProjectile::HandleHit(UPrimitiveComponent* HitComponent, AActor* OtherActor,
    UPrimitiveComponent* OtherComponent, FVector NormalImpulse, const FHitResult& Hit)
{
    if (!OtherActor || OtherActor == this || OtherActor == GetOwner()) return;

    bool bDamagedCombatant = false;
    if (ULITD2CombatantComponent* TargetCombatant = OtherActor->FindComponentByClass<ULITD2CombatantComponent>())
    {
        FLITD2DamageEventPayload Payload;
        Payload.DamageType = ELITD2DamageType::Pierce;
        Payload.HitBone = Hit.BoneName;
        Payload.HitDirection = GetVelocity().GetSafeNormal();
        Payload.DamageAmount = Damage;
        Payload.ImpactForce = 0.32f;
        Payload.Penetration = Penetration;
        Payload.BleedValue = BleedValue;
        Payload.TraumaValue = 0.0f;
        Payload.DismembermentValue = 0.0f;
        Payload.bReadableSevereCause = false;

        TargetCombatant->ReceiveDamageEvent(Payload);
        bDamagedCombatant = true;
    }

    OnBoltImpact(OtherActor, bDamagedCombatant);
    Destroy();
}
