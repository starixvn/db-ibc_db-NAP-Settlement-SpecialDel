/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250904@Hughie
	Task: Migrate data from Outright to ResultDetailOutright [Redmine:#232955]
	DB: DBPRO/bodb02
*/
USE bodb02

BEGIN

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
	WHERE NOT EXISTS (SELECT 1 FROM ResultDetailOutright r WITH (NOLOCK) WHERE r.Orid = o.orid)
		 OR NOT EXISTS (SELECT 1 FROM ProviderResultDetailOutright p WITH (NOLOCK) WHERE p.Orid = o.orid)
----------------------------------------------------------------------------------------------ResultDetailOutright
	IF EXISTS (SELECT TOP 1 1 FROM @tmp_Outright)
	BEGIN
	
			-- For ResultDetailOutright
			INSERT INTO dbo.ResultDetailOutright (
				[Orid]
				,[Leagueid]
				,[Teamid]
				,[Result]
				,[ResultStatusID]
				,[SettlementStatusID]
				,[IsDeadheat]
				,[CreatedBy]
				,[CreatedDate]
				,[ModifiedBy]
				,[ModifiedDate]
				,[RepUpdateTime]
				,[OtherInfo]
			)
			SELECT 
				[Orid]
				,[leagueid]
				,[Teamid]
				,[status]
				,0
				,0
				,[IsDeadHeat]
				,[creator]
				,[eventdate]
				,NULL
				,NULL
				,GETDATE()
				,NULL
			FROM @tmp_Outright o;

			-- For ProviderResultDetailOutright
			INSERT INTO dbo.ProviderResultDetailOutright (
				[Orid]
				,[SourceId]
				,[Leagueid]
				,[Teamid]
				,[Result]
				,[CreatedBy]
				,[CreatedDate]
				,[RepUpdateTime]
				,[OtherInfo]
			)
			SELECT 
				[Orid]
				,1001
				,[leagueid]
				,[Teamid]
				,[status]
				,[creator]
				,[eventdate]
				,GETDATE()
				,NULL
			FROM @tmp_Outright o;
	END
END