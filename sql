
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




=======================================================================


USE YourDatabaseName;
GO

-- Options: READ, INSERT, UPDATE, DELETE
DECLARE @SortBy VARCHAR(10) = 'READ';

;WITH ReadActivity AS
(
    SELECT
        object_id,
        SUM(user_seeks) AS Seeks,
        SUM(user_scans) AS Scans,
        SUM(user_lookups) AS Lookups
    FROM sys.dm_db_index_usage_stats
    WHERE database_id = DB_ID()
    GROUP BY object_id
),
WriteActivity AS
(
    SELECT
        os.object_id,
        SUM(os.leaf_insert_count) AS Inserts,
        SUM(os.leaf_update_count) AS Updates,
        SUM(
            os.leaf_delete_count +
            os.leaf_ghost_count
        ) AS Deletes
    FROM sys.dm_db_index_operational_stats(
        DB_ID(), NULL, NULL, NULL
    ) os
    INNER JOIN sys.indexes i
        ON os.object_id = i.object_id
       AND os.index_id = i.index_id
    WHERE i.type IN (0, 1)
    GROUP BY os.object_id
)
SELECT TOP (30)
    SCHEMA_NAME(t.schema_id) AS SchemaName,
    t.name AS TableName,

    ISNULL(r.Seeks, 0) +
    ISNULL(r.Scans, 0) +
    ISNULL(r.Lookups, 0) AS ReadOperations,

    ISNULL(w.Inserts, 0) AS InsertOperations,
    ISNULL(w.Updates, 0) AS UpdateOperations,
    ISNULL(w.Deletes, 0) AS DeleteOperations,

    ISNULL(r.Seeks, 0) AS IndexSeeks,
    ISNULL(r.Scans, 0) AS IndexScans,
    ISNULL(r.Lookups, 0) AS IndexLookups

FROM sys.tables t
LEFT JOIN ReadActivity r
    ON t.object_id = r.object_id
LEFT JOIN WriteActivity w
    ON t.object_id = w.object_id

WHERE t.is_memory_optimized = 0
  AND EXISTS (
      SELECT 1
      FROM sys.indexes i
      WHERE i.object_id = t.object_id
        AND i.type IN (0, 1)
  )

ORDER BY
    CASE @SortBy
        WHEN 'READ' THEN
            ISNULL(r.Seeks, 0) +
            ISNULL(r.Scans, 0) +
            ISNULL(r.Lookups, 0)
        WHEN 'INSERT' THEN ISNULL(w.Inserts, 0)
        WHEN 'UPDATE' THEN ISNULL(w.Updates, 0)
        WHEN 'DELETE' THEN ISNULL(w.Deletes, 0)
    END DESC;

==============================================================


USE YourDatabaseName;
GO

SELECT TOP (50)
    SCHEMA_NAME(t.schema_id) AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,

    ISNULL(s.user_seeks, 0) AS IndexSeeks,
    ISNULL(s.user_scans, 0) AS IndexScans,
    ISNULL(s.user_lookups, 0) AS IndexLookups,

    ISNULL(s.user_seeks, 0)
      + ISNULL(s.user_scans, 0)
      + ISNULL(s.user_lookups, 0) AS TotalReads,

    ISNULL(s.user_updates, 0) AS TotalWrites,

    s.last_user_seek AS LastSeek,
    s.last_user_scan AS LastScan,
    s.last_user_update AS LastWrite

FROM sys.tables t

INNER JOIN sys.indexes i
    ON t.object_id = i.object_id

LEFT JOIN sys.dm_db_index_usage_stats s
    ON s.object_id = i.object_id
    AND s.index_id = i.index_id
    AND s.database_id = DB_ID()

WHERE i.type = 2
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND i.is_unique = 0
  AND t.is_ms_shipped = 0

ORDER BY
    ISNULL(s.user_updates, 0) DESC,
    TotalReads ASC;





