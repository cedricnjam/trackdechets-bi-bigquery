-- Pipeline analytique BigQuery : Trackdéchets
-- Source : data.gouv.fr (Données statistiques relatives aux déchets dangereux)
-- Vue : v_analytics_avancee

CREATE OR REPLACE VIEW `dechets_data.v_analytics_avancee` AS
WITH base AS (
    SELECT
        semaine,
        EXTRACT(YEAR FROM semaine) AS annee,
        EXTRACT(ISOWEEK FROM semaine) AS num_semaine,
        quantite_recue,
        quantite_traitee,
        quantite_traitee_operations_finales AS qte_finale,
        quantite_traitee_operations_non_finales AS qte_non_finale
    FROM
        `dechets_data.statistiques_brutes`
    WHERE
        semaine IS NOT NULL
),
kpis_calcules AS (
    SELECT
        semaine,
        annee,
        num_semaine,
        ROUND(quantite_recue, 2) AS tonnes_recues,
        ROUND(quantite_traitee, 2) AS tonnes_traitees,
        
        -- Ratio d'absorption opérationnelle (%)
        ROUND(SAFE_DIVIDE(quantite_traitee, quantite_recue) * 100, 2) AS taux_absorption_pct,
        
        -- Part des opérations finales de traitement (%)
        ROUND(SAFE_DIVIDE(qte_finale, quantite_traitee) * 100, 2) AS part_operations_finales_pct,
        
        -- Moyenne mobile 4 semaines pour lisser la tendance
        ROUND(AVG(quantite_traitee) OVER(
            ORDER BY semaine 
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ), 2) AS moyenne_mobile_4semaines_tonnes,
        
        -- Variation semaine par semaine (WoW %)
        ROUND(
            SAFE_DIVIDE(
                quantite_traitee - LAG(quantite_traitee, 1) OVER(ORDER BY semaine),
                LAG(quantite_traitee, 1) OVER(ORDER BY semaine)
            ) * 100, 
        2) AS variation_wow_pct,
        
        -- Détection d'anomalies statistiques (+/- 2 écarts-types)
        CASE 
            WHEN quantite_traitee > (AVG(quantite_traitee) OVER() + 2 * STDDEV(quantite_traitee) OVER()) THEN 'Pic anormal'
            WHEN quantite_traitee < (AVG(quantite_traitee) OVER() - 2 * STDDEV(quantite_traitee) OVER()) THEN 'Creux anormal'
            ELSE 'Normal'
        END AS statut_volume
    FROM
        base
)
SELECT * FROM kpis_calcules;