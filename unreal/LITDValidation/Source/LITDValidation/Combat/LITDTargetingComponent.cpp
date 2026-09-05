#include "Combat/LITDTargetingComponent.h"
#include "GameFramework/Actor.h"

AActor* ULITDTargetingComponent::ChooseSoftTarget(const TArray<AActor*>& Candidates, FVector DesiredDirection, FVector CameraForward, const FLITDTargetingProfile& Profile) const
{
    const AActor* OwnerActor = GetOwner();
    if (!OwnerActor)
    {
        return nullptr;
    }

    DesiredDirection = DesiredDirection.GetSafeNormal();
    CameraForward = CameraForward.GetSafeNormal();
    const FVector Origin = OwnerActor->GetActorLocation();
    AActor* BestTarget = nullptr;
    float BestScore = -BIG_NUMBER;

    for (AActor* Candidate : Candidates)
    {
        if (!IsValid(Candidate) || Candidate == OwnerActor)
        {
            continue;
        }

        const FVector ToTarget = Candidate->GetActorLocation() - Origin;
        const float Distance = ToTarget.Size();
        if (Distance <= KINDA_SMALL_NUMBER || Distance > Profile.MaxRange)
        {
            continue;
        }

        const FVector Direction = ToTarget / Distance;
        const float DirectionScore = DesiredDirection.IsNearlyZero() ? 0.0f : FVector::DotProduct(DesiredDirection, Direction);
        const float CameraScore = CameraForward.IsNearlyZero() ? 0.0f : FVector::DotProduct(CameraForward, Direction);
        const float DistanceScore = 1.0f - FMath::Clamp(Distance / FMath::Max(Profile.MaxRange, 1.0f), 0.0f, 1.0f);
        const float Score = DirectionScore * Profile.DirectionWeight + CameraScore * Profile.CameraWeight + DistanceScore * Profile.DistanceWeight;

        if (Score > BestScore)
        {
            BestScore = Score;
            BestTarget = Candidate;
        }
    }
    return BestTarget;
}
