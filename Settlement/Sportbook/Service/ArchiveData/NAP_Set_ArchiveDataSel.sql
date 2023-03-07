/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ArchiveDataSel]   
	@Date DATE
	,@BatchNo INT = 2000
	,@TableName VARCHAR(50)
	,@JsonInfo VARBINARY(MAX) OUTPUT

AS  
/* 
	 Creator: Kathy  
	 Date: 20230308@Kathy  
	 Task: backup data of 2 table single_calculate_queue & parlay_calculate_queue [Redmine:#]  
	  
	   
	 Revisions:  
		- 20230308@Kathy: create SP [Redmine:#]  
		
	 Param's Explanation:  
    
*/  
BEGIN  
	SET NOCOUNT ON  

	IF @TableName = 'Single_Calculate_Queue'
	BEGIN
		SET @JsonInfo = COMPRESS((
			SELECT	TOP (@BatchNo)
					s.keyid AS 'k'
					, s.matchid AS 'm'
					, m.eventdate AS 'evd'
					, s.IsCalculating AS 'i'
					, s.AdminId AS 'aid'
					, s.IP AS 'ip'
					, s.Starttime AS 'st'
					, s.Action AS 'a'
					, s.sqlCommand AS 's'
					, s.TryCount AS 't'
					, s.execTime AS 'et'
					, s.duration AS 'd'
			FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
				INNER JOIN dbo.match m WITH(NOLOCK)
					ON s.matchid = m.matchid
			WHERE	Starttime < @Date
			ORDER BY keyid
			FOR JSON PATH 
		)
		)
	END
	ELSE IF @TableName = 'Parlay_Calculate_Queue'
	BEGIN
		SET @JsonInfo = COMPRESS((
			SELECT	TOP (@BatchNo)
					p.keyid AS 'k'
					, p.matchid AS 'm'
					, m.eventdate AS 'evd'
					, p.IsCalculating AS 'i'
					, p.Creator AS 'aid'
					, p.IP AS 'ip'
					, p.Starttime AS 'st'
					, p.Action AS 'a'
					, p.TryCount AS 't'
					, p.execTime AS 'et'
					, p.duration AS 'd'
			FROM	dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
				INNER JOIN dbo.match m WITH(NOLOCK)
					ON p.matchid = m.matchid
			WHERE Starttime < @Date
			ORDER BY keyid
			FOR JSON PATH
		))
	END

END  
GO