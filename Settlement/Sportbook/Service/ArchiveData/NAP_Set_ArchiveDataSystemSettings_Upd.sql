/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ArchiveDataSystemSettings_Upd]   
	@TableName VARCHAR(50)
	,@JsonInfo VARBINARY(MAX)
AS  
/* 
	 Creator: Max  
	 Date: 20250718@Max  
	 Task: Support Daily Settlement Report for Vega project [Redmine: #233410]

	 Revisions:  
		- 20250718@Max: create SP [Redmine:#233410]    
		
	 Param's Explanation:  
    
*/  
BEGIN  
	SET NOCOUNT ON  

	DECLARE @Decompress_JsonInfo NVARCHAR(MAX), @LastRow INT
	DECLARE @tmpKeyId TABLE (KeyId INT)

	SET @Decompress_JsonInfo = CAST(DECOMPRESS(@JsonInfo) AS NVARCHAR(MAX))

	INSERT INTO @tmpKeyId(KeyId)
	SELECT k AS KeyId
	FROM	OPENJSON(@Decompress_JsonInfo)
		WITH(k INT
		)

	SELECT @LastRow = MAX(keyid) FROM @tmpKeyId

	IF @TableName = 'Single_Calculate_Queue'
	BEGIN
		UPDATE	s SET VValue = @LastRow
		FROM	dbo.SystemSettings s WITH(ROWLOCK, UPDLOCK)
		WHERE	VName = 'Single_Calculate_Queue'
	END
	ELSE IF @TableName = 'Parlay_Calculate_Queue'
	BEGIN
		UPDATE	s SET VValue = @LastRow
		FROM	dbo.SystemSettings s WITH(ROWLOCK, UPDLOCK)
		WHERE	VName = 'Parlay_Calculate_Queue'
	END

END  
GO