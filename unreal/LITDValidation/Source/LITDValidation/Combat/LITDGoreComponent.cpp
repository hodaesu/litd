#include "Combat/LITDGoreComponent.h"

bool ULITDGoreComponent::ApplyLocalizedDamage(const ELITDBodyZone Zone, const float Damage, const ELITDDamageNature Nature, const FVector HitLocation, const FVector Impulse)
{
    FLITDBodyPartState* Part = FindBodyPart(Zone);
    if (!Part || Damage <= 0.0f || Part->bSevered)
    {
        return false;
    }

    Part->AccumulatedTrauma += Damage;
    Part->Integrity = FMath::Max(0.0f, Part->Integrity - Damage);
    OnLocalizedHit.Broadcast(Zone, Damage, Nature);

    if (Part->bCanSever && DamageCanSever(Nature) && Part->AccumulatedTrauma >= Part->SeverThreshold)
    {
        Part->bSevered = true;
        OnLimbSevered.Broadcast(Zone, HitLocation, Impulse);
        return true;
    }
    return false;
}

bool ULITDGoreComponent::IsSevered(const ELITDBodyZone Zone) const
{
    const FLITDBodyPartState* Part = FindBodyPart(Zone);
    return Part && Part->bSevered;
}

FLITDBodyPartState* ULITDGoreComponent::FindBodyPart(const ELITDBodyZone Zone)
{
    return BodyParts.FindByPredicate([Zone](const FLITDBodyPartState& Part) { return Part.Zone == Zone; });
}

const FLITDBodyPartState* ULITDGoreComponent::FindBodyPart(const ELITDBodyZone Zone) const
{
    return BodyParts.FindByPredicate([Zone](const FLITDBodyPartState& Part) { return Part.Zone == Zone; });
}

bool ULITDGoreComponent::DamageCanSever(const ELITDDamageNature Nature)
{
    return Nature == ELITDDamageNature::Slash || Nature == ELITDDamageNature::Ash || Nature == ELITDDamageNature::Portal;
}
