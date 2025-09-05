/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250904@Hughie
	Task: Migrate data from Outright to ResultDetailOutright [Redmine:#232955]
	DB: DBPRO/bodb02
*/
USE bodb02

BEGIN
	DECLARE @StartRow INT
			,@StopRow INT
			

	DECLARE @tmp_Outright TABLE (
		[Orid]			INT
		,[leagueid]		INT
		,[Teamid]		INT
		,[status]		VARCHAR(10)
		,[IsDeadHeat]	BIT
		,[creator]		INT
		,[eventdate]	DATETIME
		
	)
	INSERT INTO @tmp_Outright (
	[Orid]			
	,[leagueid]		
	,[Teamid]		
	,[status]		
	,[IsDeadHeat]	
	,[creator]		
	,[eventdate]	
	)
	SELECT 
	o.[orid]
	,o.[leagueid]		
	,o.[Teamid]		
	,o.[status]		
	,o.[IsDeadHeat]	
	,o.[creator]		
	,o.[eventdate]	
	FROM outright o WITH (NOLOCK)
		LEFT JOIN ResultDetailOutright r WITH (NOLOCK) ON r.Orid = o.orid
		LEFT JOIN ProviderResultDetailOutright p WITH (NOLOCK) ON p.Orid = o.orid
	WHERE r.Orid is null or p.Orid is null
----------------------------------------------------------------------------------------------ResultDetailOutright

	
	MERGE dbo.ResultDetailOutright TARGET
	USING (
			SELECT	
			[Orid]
			,[leagueid]
			,[Teamid]
			,[status]
			,0 AS [ResultStatusID]
			,0 AS [SettlementStatusID]
			,[IsDeadHeat]
			,NULL AS [SumWon]
			,[creator]
			,[eventdate]
			,NULL AS [ModifiedBy]
			,NULL AS [ModifiedDate]
			,GETDATE() AS [RepUpdateTime]
			,NULL AS [OtherInfo]
		FROM @tmp_Outright o
		) AS SOURCE ON TARGET.Orid = SOURCE.Orid			
	WHEN MATCHED THEN 
			UPDATE SET	TARGET.Result				= TARGET.Result
						,TARGET.ResultStatusId		= TARGET.ResultStatusId
						,TARGET.SettlementStatusID	= TARGET.SettlementStatusID
						,TARGET.IsDeadheat			= TARGET.IsDeadheat	
						,TARGET.ModifiedDate		= TARGET.ModifiedDate
						,TARGET.ModifiedBy			= TARGET.ModifiedBy	
	WHEN NOT MATCHED BY TARGET THEN
		INSERT(
			Orid
			,Leagueid
			,Teamid
			,Result
			,ResultStatusID
			,SettlementStatusID
			,IsDeadheat
			,CreatedBy
			,CreatedDate
			,ModifiedBy
			,ModifiedDate
		)               
		VALUES(
			 SOURCE.[Orid]
			,SOURCE.[leagueid]
			,SOURCE.[Teamid]
			,SOURCE.[status]
			,0
			,0
			,SOURCE.[IsDeadHeat]
			,NULL
			,SOURCE.[creator]
			,SOURCE.[eventdate]
			,NULL
			,NULL
			,GETDATE() 
			,NULL
		);

------------------------------------------------------ProviderResultDetailOutright
		MERGE dbo.ProviderResultDetailOutright TARGET
	USING (
			SELECT	
			[Orid]
			,[leagueid]
			,[Teamid]
			,[status]
			,0 AS [ResultStatusID]
			,0 AS [SettlementStatusID]
			,[IsDeadHeat]
			,NULL AS [SumWon]
			,[creator]
			,[eventdate]
			,NULL AS [ModifiedBy]
			,NULL AS [ModifiedDate]
			,GETDATE() AS [RepUpdateTime]
			,NULL AS [OtherInfo]
		FROM @tmp_Outright o
		) AS SOURCE ON TARGET.Orid = SOURCE.Orid			
	WHEN MATCHED THEN 
			UPDATE SET	TARGET.Result				= TARGET.Result
						,TARGET.ResultStatusId		= TARGET.ResultStatusId
						,TARGET.SettlementStatusID	= TARGET.SettlementStatusID
						,TARGET.IsDeadheat			= TARGET.IsDeadheat	
						,TARGET.ModifiedDate		= TARGET.ModifiedDate
						,TARGET.ModifiedBy			= TARGET.ModifiedBy	
	WHEN NOT MATCHED BY TARGET THEN
		INSERT(
			Orid
			,Leagueid
			,Teamid
			,Result
			,ResultStatusID
			,SettlementStatusID
			,IsDeadheat
			,CreatedBy
			,CreatedDate
			,ModifiedBy
			,ModifiedDate
		)               
		VALUES(
			 SOURCE.[Orid]
			,SOURCE.[leagueid]
			,SOURCE.[Teamid]
			,SOURCE.[status]
			,0
			,0
			,SOURCE.[IsDeadHeat]
			,NULL
			,SOURCE.[creator]
			,SOURCE.[eventdate]
			,NULL
			,NULL
			,GETDATE() 
			,NULL
		);
END