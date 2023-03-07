/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ArchiveDataDel]   
	@TableName VARCHAR(50)
	,@JsonInfo VARBINARY(MAX)
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

	DECLARE @Decompress_JsonInfo NVARCHAR(MAX)
	DECLARE @tmpKeyId TABLE (KeyId INT)

	SET @Decompress_JsonInfo = CAST(DECOMPRESS(@JsonInfo) AS NVARCHAR(MAX))

	INSERT INTO @tmpKeyId(KeyId)
	SELECT k AS KeyId
	FROM	OPENJSON(@Decompress_JsonInfo)
		WITH(k INT
		)

	IF @TableName = 'Single_Calculate_Queue'
	BEGIN
		DELETE	s
		FROM	dbo.Single_Calculate_Queue s WITH(ROWLOCK, UPDLOCK)
		WHERE	EXISTS (SELECT TOP 1 1 FROM @tmpKeyId t WHERE t.KeyId = s.keyId)
	END
	ELSE IF @TableName = 'Parlay_Calculate_Queue'
	BEGIN
		DELETE	p
		FROM	dbo.Parlay_Calculate_Queue p WITH(ROWLOCK, UPDLOCK)
		WHERE	EXISTS (SELECT TOP 1 1 FROM @tmpKeyId t WHERE t.KeyId = p.keyId)
	END

END  
GO