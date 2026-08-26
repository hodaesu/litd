#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "LITDValidationHUD.generated.h"

UCLASS()
class LITDVALIDATION_API ALITDValidationHUD : public AHUD
{
    GENERATED_BODY()

public:
    virtual void DrawHUD() override;

private:
    void DrawLine(const FString& Text, float X, float& Y, const FLinearColor& Color, float Scale = 1.0f);
};
