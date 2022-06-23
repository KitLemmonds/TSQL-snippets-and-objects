USE [master]
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_IndexStats]
@tablename NVARCHAR(776)=NULL
AS
/*
Analyze index usage, compression, size, etc for @tablename.

To use as a keyboard shortcut in SSMS, run in master and
run the following to ensure correct db-context:

EXEC sp_ms_marksystemobject 'sp_indexStats' 

Then set 'sp_IndexStats' in your keyboard shortcut of choice 
from SSMS's Tools|Options\Environment\Keyboard Shortcuts. 
*/
SELECT		s.name schema_name, 
			OBJECT_NAME(i.OBJECT_ID) Table_Name,
			i.index_id,i.name AS Index_Name,
			i.type_desc Index_Type,
			p.data_compression_desc, 
			SUM(PS.[used_page_count]) * 8 IndexSizeKB,
			CONVERT(INT,ROUND(AVG(f.avg_fragmentation_in_percent),0)) Pct_Fragmentation,
			ius.user_seeks AS NumOfSeeks,
			ius.user_scans AS NumOfScans,
			ius.user_lookups AS NumOfLookups,
			ius.user_updates AS NumOfUpdates,  
			CONVERT(INT,ROUND(ios.range_scan_count * 100.0 / case when (ios.range_scan_count + ios.leaf_insert_count+ios.leaf_delete_count + ios.leaf_update_count + 
				ios.leaf_page_merge_count + ios.singleton_lookup_count)=0 then NULL else  (ios.range_scan_count + ios.leaf_insert_count + ios.leaf_delete_count + 
				ios.leaf_update_count+ios.leaf_page_merge_count+ios.singleton_lookup_count) END,0)) AS [Percent_Scan],
			CONVERT(INT,ROUND(ios.leaf_update_count * 100.0 / case 
				WHEN (ios.range_scan_count + ios.leaf_insert_count+ios.leaf_delete_count + ios.leaf_update_count + ios.leaf_page_merge_count + ios.singleton_lookup_count)=0 
				THEN NULL else (ios.range_scan_count + ios.leaf_insert_count + ios.leaf_delete_count + ios.leaf_update_count + ios.leaf_page_merge_count 
				+ ios.singleton_lookup_count )  end,0)) AS [Percent_Update],
			i.fill_factor,
			ius.last_user_seek AS LastSeek,
			ius.last_user_scan AS LastScan,
			ius.last_user_lookup AS LastLookup,
			ius.last_user_update AS LastUpdate 
FROM		sys.indexes i 
			INNER JOIN sys.dm_db_index_usage_stats ius ON ius.index_id = i.index_id AND ius.database_id=db_id() AND ius.OBJECT_ID = i.OBJECT_ID 
			INNER JOIN sys.dm_db_partition_stats ps on ps.object_id=i.object_id 
			inner join sys.partitions p on ps.partition_id=p.partition_id and p.index_id=i.index_id 
			inner join sys.objects o on i.object_id=o.object_id 
			inner join sys.schemas s on o.schema_id=s.schema_id  
			CROSS apply sys.dm_db_index_operational_stats(db_id(),i.object_id, i.index_id,ps.partition_number)ios 
			CROSS APPLY sys.dm_db_index_physical_stats (DB_ID(), ios.object_id, ios.index_id, NULL, NULL)f
WHERE		OBJECTPROPERTY(i.OBJECT_ID,'IsUserTable') = 1 
			AND i.object_id=object_id(@tablename)   
GROUP BY	s.name, 
			OBJECT_NAME(i.OBJECT_ID),
			i.index_id,
			i.name,
			i.type_desc,
			p.data_compression_desc,
			ius.user_seeks,
			ius.user_scans,
			ius.user_lookups,
			ius.user_updates,
			ios.range_scan_count * 100.0 / case 
				WHEN (ios.range_scan_count + ios.leaf_insert_count+ios.leaf_delete_count + ios.leaf_update_count + ios.leaf_page_merge_count + ios.singleton_lookup_count)=0 
				THEN NULL else  (ios.range_scan_count + ios.leaf_insert_count + ios.leaf_delete_count + ios.leaf_update_count + 
					ios.leaf_page_merge_count + ios.singleton_lookup_count) end,
			ios.leaf_update_count * 100.0 / case 
				WHEN (ios.range_scan_count + ios.leaf_insert_count + ios.leaf_delete_count + ios.leaf_update_count + ios.leaf_page_merge_count + ios.singleton_lookup_count)=0 
				THEN NULL else (ios.range_scan_count + ios.leaf_insert_count + ios.leaf_delete_count + ios.leaf_update_count + 
					ios.leaf_page_merge_count + ios.singleton_lookup_count )  end, 
			i.fill_factor,
			ius.last_user_seek,
			ius.last_user_scan,
			ius.last_user_lookup,
			ius.last_user_update
GO


