/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelNumberGame]
	@FromDate		DATETIME,
	@ToDate			DATETIME = NULL,
	@matchcode		NVARCHAR(50) = '',
	@matchstatus	NVARCHAR(50) = ''
AS
/*
	Created: 20120831@Dan
	Task: Get Number Game result 
	DB: DBPRO.bodb02  
	Original: [Acc_Result_MatchSelNumberGameByLeague]
  
	Revisions:   
		- 20150226@Kathy: Don't show match in match14 [Redmine:#29990]
		- 20200218@Sol: Incorporate Number Game - Color Ball - Move to DBPRO [Redmine:#128203]
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]

	Param explanation:  
		@matchcode: match code
		@matchstatus: 0: all, 1: running; 2: closed; 3: completed; 4: refund;
*/  
BEGIN

	SET NOCOUNT ON  
	DECLARE @eventstatus NVARCHAR(50),
			@isRefund BIT,
			@matchid INT

	IF @ToDate IS NULL
	BEGIN
		SELECT @ToDate = DATEADD(s,-1, DATEADD(d, 1, @FromDate))    
	END  

	SELECT @matchcode = ISNULL(@matchcode,'')
	-- if entering matcode, ignore other params (excep FromDate, ToDate)
	IF (@matchcode <> '')
	BEGIN
		SELECT @eventstatus= '', 
				@isRefund = NULL
		BEGIN TRY	
			SET @matchid = CASE WHEN ISNUMERIC(@matchcode) = 1 THEN CAST(@matchcode AS INT) ELSE NULL END
		END TRY
		BEGIN CATCH
			SET @matchid=NULL
		END CATCH				
	END
	ELSE
	BEGIN
		SELECT @eventstatus = CASE WHEN @matchstatus IN ('all', 'refund')  THEN '' ELSE @matchstatus END,
			@isRefund = CASE @matchstatus WHEN 'refund' THEN 1 
										WHEN 'all' THEN NULL
										ELSE 0 END			
	END

	SELECT   
		m.betstatus,   
		m.leagueid,  
		m.matchid,
		m.matchcode,  
		m.eventdate,   
		m.kickofftime,
		m.homeid,
		CASE WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT'   
			 WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'  
			 WHEN m.betstatus LIKE 'Refund%' THEN 'Refund'   
			 ELSE m.eventstatus END AS eventstatus,
		CAST(CASE WHEN m.betstatus LIKE 'Refund' THEN 1   
			 ELSE 0 END AS BIT) AS IsRefund,
		CAST(b.number AS VARCHAR(20)) AS number
	FROM  
	   (
			SELECT sporttype, betstatus, matchid, matchcode, leagueid, eventdate, eventstatus, kickofftime, homeid  
			FROM MATCH WITH(NOLOCK)  
			WHERE	eventdate BETWEEN  @FromDate  AND  @ToDate 
					AND sporttype=161
					AND ISNULL(IsDeleted,0) = 0
	   ) AS m 
		LEFT OUTER JOIN (
							SELECT matchid, seq, number, Color FROM bingoball WITH(NOLOCK)
						) AS B ON B.matchid = m.matchid
		LEFT OUTER JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid  
	WHERE (
			m.eventstatus NOT IN ('internal','running')  
				OR (m.eventstatus = 'running' AND mr.ishtcal=1)
			)		
			AND (@matchcode = '' or (m.matchid = @matchid OR m.matchcode = @matchcode)) 
			AND (@eventstatus='' or eventstatus in (@eventstatus)) 
			AND (@isRefund is null or 
					(@isRefund =1 and betstatus like 'Refund%') or
					(@isRefund =0 and ISNULL(betstatus,'') not like 'Refund%') 
				)	  
	ORDER BY m.leagueid, m.matchid, b.seq

END
GO