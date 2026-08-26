#include "LITDValidationHUD.h"
#include "LITDValidationGameMode.h"
#include "Engine/Canvas.h"
#include "Engine/Engine.h"

void ALITDValidationHUD::DrawHUD()
{
    Super::DrawHUD();
    const ALITDValidationGameMode* Mode = GetWorld() ? Cast<ALITDValidationGameMode>(GetWorld()->GetAuthGameMode()) : nullptr;
    if (!Mode || !Canvas || !GEngine)
    {
        return;
    }

    const float Width = 360.0f;
    DrawRect(FLinearColor(0.01f, 0.015f, 0.025f, 0.92f), Canvas->SizeX - Width - 18.0f, 18.0f, Width, Canvas->SizeY - 36.0f);
    float Y = 38.0f;
    const float X = Canvas->SizeX - Width;
    DrawLine(TEXT("LITD — COMPARATIF UNREAL"), X, Y, FLinearColor(0.83f, 0.68f, 0.40f), 1.2f);
    DrawLine(FString::Printf(TEXT("%d/11 contrôles validés"), Mode->CompletedCount()), X, Y, FLinearColor::White);

    static const TArray<TPair<FName, FString>> Labels = {
        {TEXT("movement"), TEXT("Déplacement / caméra")},
        {TEXT("dialogue"), TEXT("Dialogue avec Ilyan")},
        {TEXT("chest"), TEXT("Ouverture du coffre")},
        {TEXT("loot"), TEXT("Ajout du butin")},
        {TEXT("combat_started"), TEXT("Combat et dégâts")},
        {TEXT("combat_finished"), TEXT("Quatre ennemis vaincus")},
        {TEXT("consumables"), TEXT("Soins et grenades préparés")},
        {TEXT("psychology"), TEXT("Peur / Espoir / Folie")},
        {TEXT("injury"), TEXT("Blessure persistante")},
        {TEXT("ash_guidance"), TEXT("Cendres sur demande")},
        {TEXT("save_roundtrip"), TEXT("Snapshot sauvegardé / relu")}
    };
    const TMap<FName, bool>& Checks = Mode->GetChecks();
    for (const TPair<FName, FString>& Label : Labels)
    {
        const bool bPassed = Checks.FindRef(Label.Key);
        DrawLine(FString(bPassed ? TEXT("✓ ") : TEXT("◇ ")) + Label.Value, X, Y,
            bPassed ? FLinearColor(0.45f, 0.82f, 0.58f) : FLinearColor(0.75f, 0.72f, 0.67f), 0.85f);
    }

    Y += 10.0f;
    DrawLine(TEXT("E / bouton bas : interagir"), X, Y, FLinearColor(0.62f, 0.58f, 0.50f), 0.82f);
    DrawLine(TEXT("Clic / gâchette : attaquer"), X, Y, FLinearColor(0.62f, 0.58f, 0.50f), 0.82f);
    DrawLine(TEXT("G / bouton haut : cendres"), X, Y, FLinearColor(0.62f, 0.58f, 0.50f), 0.82f);
    DrawLine(TEXT("F8 : réinitialiser"), X, Y, FLinearColor(0.62f, 0.58f, 0.50f), 0.82f);
    Y += 12.0f;
    DrawLine(Mode->GetMessage(), X, Y, FLinearColor(0.90f, 0.84f, 0.72f), 0.82f);
    if (!Mode->GetInventorySummary().IsEmpty())
    {
        DrawLine(TEXT("Inventaire : ") + Mode->GetInventorySummary(), X, Y, FLinearColor(0.83f, 0.68f, 0.40f), 0.82f);
    }
}

void ALITDValidationHUD::DrawLine(
    const FString& Text, float X, float& Y, const FLinearColor& Color, float Scale)
{
    UFont* Font = GEngine ? GEngine->GetSmallFont() : nullptr;
    if (!Font)
    {
        return;
    }
    DrawText(Text, Color, X, Y, Font, Scale, false);
    Y += 24.0f * Scale;
}
