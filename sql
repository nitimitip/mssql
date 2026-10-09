
SELECT TOP 30
    OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id)
        AS SchemaName,
    OBJECT_NAME(mid.object_id, mid.database_id)
        AS TableName,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.user_seeks,
    migs.user_scans,
    migs.avg_user_impact AS EstimatedImpactPercent,
    CAST(
        migs.avg_total_user_cost *
        migs.avg_user_impact *
        (migs.user_seeks + migs.user_scans)
        AS DECIMAL(28,2)
    ) AS ImprovementScore
FROM sys.dm_db_missing_index_details mid
JOIN sys.dm_db_missing_index_groups mig
    ON mid.index_handle = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats migs
    ON mig.index_group_handle = migs.group_handle
WHERE mid.database_id = DB_ID()
ORDER BY ImprovementScore DESC;






============================table----------------


USE YourDatabaseName;
GO

DECLARE @TableName SYSNAME = 'dbo.YourTableName';

SELECT
    OBJECT_NAME(mid.object_id, mid.database_id) AS TableName,
    mid.equality_columns AS EqualityColumns,
    mid.inequality_columns AS InequalityColumns,
    mid.included_columns AS IncludedColumns,

    migs.user_seeks AS UserSeeks,
    migs.user_scans AS UserScans,

    CAST(migs.avg_user_impact AS DECIMAL(10,2))
        AS EstimatedImprovementPercent,

    CAST(
        migs.avg_total_user_cost *
        migs.avg_user_impact *
        (migs.user_seeks + migs.user_scans)
        AS DECIMAL(28,2)
    ) AS ImprovementScore,

    'CREATE NONCLUSTERED INDEX IX_Missing_' +
        CAST(mid.index_handle AS VARCHAR(20)) +
        ' ON ' + mid.statement +
        ' (' +
        ISNULL(mid.equality_columns, '') +
        CASE
            WHEN mid.equality_columns IS NOT NULL
             AND mid.inequality_columns IS NOT NULL
            THEN ', ' ELSE ''
        END +
        ISNULL(mid.inequality_columns, '') +
        ')' +
        ISNULL(
            ' INCLUDE (' + mid.included_columns + ')',
            ''
        ) AS SuggestedIndexSQL

FROM sys.dm_db_missing_index_details mid
JOIN sys.dm_db_missing_index_groups mig
    ON mid.index_handle = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats migs
    ON mig.index_group_handle = migs.group_handle

WHERE mid.database_id = DB_ID()
  AND mid.object_id = OBJECT_ID(@TableName, 'U')

ORDER BY ImprovementScore DESC;










