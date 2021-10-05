/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
create procedure dbo.SSB_Send_Message @MessageContent nvarchar(max)
	, @FunctionName varchar(200)
	, @MessageType varchar(200)
	, @ErrorCode int = 0 output
	, @ErrorMessage varchar(max) = '' output
as
/*  Created: Patrick@20210801
	Task: Send message
	DB: DBTXN-bodb02,SBSETTLE-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
*/
begin
	set nocount on

	declare @__conversationHandle uniqueidentifier, @__contractName varchar(200)
	
	select top(1) @__contractName = ContractName 
	from sb.ConfigurationReferenceDetail with(nolock) 
	where FunctionName = @FunctionName 
		and MessageType = @MessageType

	exec dbo.SSB_ConversationPick @FunctionName = @FunctionName
		, @ContractName = @__contractName
		, @ConversationHandle = @__conversationHandle output
	
	if @__conversationHandle is null
	begin
		select @ErrorCode = 1, @ErrorMessage = 'can not pick convesation handle. please check your setting!!!'
		return
	end
	else 
	begin
		exec dbo.SSB_MsgSent @ConversationHandle = @__conversationHandle
			, @MessageContent = @MessageContent
			, @MessageType = @MessageType
			, @ErrorCode = @ErrorCode output
			, @ErrorMessage = @ErrorMessage output
		
		if @errorCode <> 0
			set @ErrorCode = 1
		else 
			set @ErrorCode = 0	
	end
end
go