#tag Module
Protected Module pgdbconf
	#tag Method, Flags = &h21
		Private Function Count(extends db as PostgreSQLDatabase, recordObject as pgdbconfRecord) As integer
		  // counts records that match the (language/application/user/section/key) criterion
		  
		  mLastError = ""
		  
		  If IsNull(recordObject) then mLastError = "Invalid search parameters"
		  If recordObject.key.Trim = "" then mLastError = "No key entered!"
		  If validateSession(db) = false then mLastError = "Database session is not valid"
		  if recordObject.TableName = "" then mLastError = "No table name defined"
		  
		  if mLastError <> "" then return -1
		  
		  
		  dim WHERE as string
		  WHERE = "language = " + if(recordObject.language.Trim = "" , "'" + DefaultLanguage + "'" , "'" + recordObject.language.Trim.Uppercase + "'") + " AND "
		  WHERE = WHERE + "application = " + if(recordObject.application.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.application.Trim.Uppercase + "'") + " AND "
		  WHERE = WHERE + "username = " + if(recordObject.user.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.user.Trim.Uppercase + "'") + " AND "
		  WHERE = WHERE + "section = " + if(recordObject.section.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.section.Trim.Uppercase + "'") + " AND "
		  WHERE = WHERE + "key = '" + recordObject.key.Trim.Uppercase + "'"
		  
		  dim query as String = "SELECT COUNT(*) FROM " + recordObject.TableName + " WHERE " + WHERE 
		  
		  dim countdata as RecordSet = db.SQLSelect(query)
		  
		  if db.error = true then 
		    mLastError = "Error querying settings table: " + db.ErrorMessage
		    Return -1
		  end if
		  
		  
		  Return countdata.IdxField(1).IntegerValue
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function pgdbconf_Append2Array(extends db as PostgreSQLDatabase, recordObject as pgdbconfRecord) As pgdbconfRecord
		  // only inserts records with the (language/application/user/section/key) combination
		  // when used repeatedy for the same combination, it effectively creates an array which can be read using ReadArray
		  
		  if validateSession(db) = false then Return new pgdbconfRecord("Database session is not valid")
		  If IsNull(recordObject) then Return new pgdbconfRecord("Invalid search parameters")
		  if recordObject.TableName = "" then return new pgdbconfRecord("No table name defined")
		  
		  if recordObject.key.Trim = "" then Return new pgdbconfRecord("Key should not be empty!")
		  
		  dim newRecord as new DatabaseRecord
		  
		  newRecord.Column("language") = if(recordObject.language.Trim = "" , DefaultLanguage , recordObject.language.Trim.Uppercase)
		  newRecord.Column("application") = if(recordObject.application.Trim = "" , GlobalName , recordObject.application.Trim.Uppercase)
		  newRecord.Column("username") = if(recordObject.user.Trim = "" , GlobalName , recordObject.user.Trim.Uppercase)
		  newRecord.Column("section") = if(recordObject.section.Trim = "" , GlobalName , recordObject.section.Trim.Uppercase)
		  newRecord.Column("key") = recordObject.key.Trim.Uppercase
		  
		  if recordObject.value <> "" then newRecord.Column("value") = recordObject.value
		  if recordObject.comment.Trim <> "" then newRecord.Column("comment") = recordObject.comment
		  
		  db.InsertRecord(recordObject.TableName , newRecord)
		  if db.Error then Return new pgdbconfRecord("Error writing settings table: " + db.ErrorMessage)
		  
		  recordObject.Error = false  // in case we got it as true
		  
		  Return recordObject
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function pgdbconf_createTable(extends db as PostgreSQLDatabase, tablename as string) As string
		  // returns empty string if OK, error message if error
		  
		  if validateSession(db) = false then return "Database session is not valid"
		  if tablename.Trim = "" then return "No table name defined"
		  
		  dim CREATETABLE as string = "CREATE TABLE " + tablename + " (objidx uuid DEFAULT uuid_in(md5(random()::text || clock_timestamp()::text)::cstring) , language TEXT NOT NULL DEFAULT '" + DefaultLanguage + "' , application TEXT NOT NULL DEFAULT '" + GlobalName + "' , username TEXT NOT NULL DEFAULT '" + GlobalName + "' , section TEXT NOT NULL DEFAULT '" + GlobalName + "' , key TEXT NOT NULL , value TEXT , comment TEXT)"
		  db.SQLExecute(CREATETABLE)
		  
		  if db.Error then return "Error creating pgdbconf table: " + db.ErrorMessage
		  
		  dim INSERTINITRECORD as String = "INSERT INTO " + tablename + " (section , key , value , comment) VALUES ('LOCALCONF' , 'INITSTAMP' , '" + date(new date).SQLDateTime + "' , 'Automatically generated by pgdbconf')"
		  db.SQLExecute(INSERTINITRECORD)
		  
		  if db.Error then 
		    dim insertErrorMsg as String = db.ErrorMessage
		    db.SQLExecute("DROP TABLE " + tablename)
		    return "Error writing system record: " + insertErrorMsg
		  end if 
		  
		  Return ""  // success
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function pgdbconf_Delete(extends db as PostgreSQLDatabase, recordObject as pgdbconfRecord) As pgdbconfRecord
		  // match criterion is either the (language/application/user/section/key) combination or objidx
		  // priority on objidx
		  
		  if IsNull(recordObject) then Return new pgdbconfRecord("Invalid search parameters")
		  if recordObject.TableName = "" then Return new pgdbconfRecord("Table name not defined")
		  if validateSession(db) = false then Return new pgdbconfRecord("Database session is not valid")
		  
		  if recordObject.objidx <> "" then  // objidx is our match criterion 
		    
		    db.SQLExecute("DELETE FROM " + recordObject.TableName + " WHERE objidx = '" + recordObject.objidx + "'")
		    if db.Error then Return new pgdbconfRecord("Error deleting from settings table: " + db.ErrorMessage)
		    
		  else // we look for the (language/application/user/section/key) combination
		    
		    if recordObject.key.Trim = "" then Return new pgdbconfRecord("Key should not be empty!")
		    
		    select case db.Count(recordObject)
		    case -1  // error
		      Return new pgdbconfRecord("Error reading config table: " + mLastError)
		    case 0  // nothing to delete
		      Return new pgdbconfRecord("No records to delete!")
		    case 1  // one record to delete
		      
		      dim WHERE as String
		      
		      WHERE = "language = " + if(recordObject.language.Trim = "" , "'" + DefaultLanguage + "'" , "'" + recordObject.language.Trim.Uppercase + "'") + " AND "
		      WHERE = WHERE + "application = " + if(recordObject.application.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.application.Trim.Uppercase + "'") + " AND "
		      WHERE = WHERE + "username = " + if(recordObject.user.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.user.Trim.Uppercase + "'") + " AND "
		      WHERE = WHERE + "section = " + if(recordObject.section.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.section.Trim.Uppercase + "'") + " AND "
		      WHERE = WHERE + "key = '" + recordObject.key.Trim.Uppercase + "'"
		      
		      db.SQLExecute("DELETE FROM " + recordObject.TableName + " WHERE " + WHERE)
		      if db.Error then Return new pgdbconfRecord("Error deleting from settings table: " + db.ErrorMessage)
		      
		    else // it's an array --this method can't act on arrays
		      Return new pgdbconfRecord("Cannot delete an entire array!")
		    end select
		    
		  end if
		  
		  Return recordObject
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function pgdbconf_LastError() As string
		  Return mLastError
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function pgdbconf_projectURL() As String
		  Return "https://github.com/gregorplop/pgdbconf"
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function pgdbconf_QueryDistinct(extends db as PostgreSQLDatabase, DistinctField as string, tablename as string, optional WHERE as string = "") As string()
		  // if error then output is a -1 sized array and LastError holds error message
		  
		  mLastError = ""
		  dim distinctValues(-1) as string
		  
		  dim allowedFields(-1) as String = Array("language" , "application" , "username" , "section" , "key" , "value")
		  if allowedFields.IndexOf(DistinctField.Lowercase) < 0 then 
		    mLastError = "Invalid field name for distinct values query!"
		    Return distinctValues
		  end if
		  
		  if validateSession(db) = false then
		    mLastError = "Database session is not valid"
		    Return distinctValues
		  end if
		  
		  if tablename.Trim = "" then
		    mLastError = "No table name defined"
		    Return distinctValues
		  end if
		  
		  if WHERE.Trim = "" then WHERE = "TRUE"
		  
		  dim dumpdata as RecordSet = db.SQLSelect("SELECT DISTINCT " + DistinctField.Lowercase + " FROM " + tablename + " WHERE " + WHERE + " ORDER BY " + DistinctField.Lowercase + " ASC")
		  
		  if db.error = true then 
		    mLastError = "Error querying settings file: " + db.ErrorMessage
		    Return distinctValues
		  end if
		  
		  while not dumpdata.EOF
		    distinctValues.Append dumpdata.IdxField(1).StringValue
		    dumpdata.MoveNext
		  wend
		  
		  Return distinctValues
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function pgdbconf_QueryGeneric(extends db as PostgreSQLDatabase, tablename as string, optional WHERE as String = "TRUE") As pgdbconfRecord()
		  // if error then output is 1-element array with .error = true and .errorMessage holds reason for error
		  // if localconf file is empty then output is an array having UBound = -1
		  
		  dim dump(-1) as pgdbconfRecord
		  
		  if validateSession(db) = false then
		    mLastError = "Database session is not valid"
		    Return dump
		  end if
		  
		  if tablename.Trim = "" then
		    mLastError = "No table name defined"
		    Return dump
		  end if
		  
		  if WHERE.Trim = "" then WHERE = "TRUE"
		  
		  dim query as string = "SELECT * FROM " + tablename + " WHERE " + WHERE + " ORDER BY language , application , username , section , key ASC"
		  dim dumpdata as RecordSet = db.SQLSelect(query)
		  
		  if db.error = true then 
		    dump.Append new pgdbconfRecord("Error querying settings table: " + db.ErrorMessage)
		    Return dump
		  end if
		  
		  dim record as pgdbconfRecord
		  
		  while not dumpdata.EOF
		    record = new pgdbconfRecord(True)
		    
		    record.objidx = dumpdata.Field("objidx").StringValue
		    record.language = dumpdata.Field("language").StringValue
		    record.application = dumpdata.Field("application").StringValue
		    record.user = dumpdata.Field("username").StringValue
		    record.section = dumpdata.Field("section").StringValue
		    record.key = dumpdata.Field("key").StringValue
		    
		    record.value = dumpdata.Field("value").StringValue
		    record.comment = dumpdata.Field("comment").StringValue
		    
		    dump.Append record
		    
		    dumpdata.MoveNext
		  wend
		  
		  Return dump
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function pgdbconf_ReadArray(extends db as PostgreSQLDatabase, recordObject as pgdbconfRecord) As pgdbconfRecord()
		  // reads all elements that matche the (language/application/user/section/key) criterion
		  // objidx is ignored if exists
		  
		  if validateSession(db) = false then Return array(new pgdbconfRecord("Database session is not valid"))
		  If IsNull(recordObject) then Return array(new pgdbconfRecord("Invalid search parameters"))
		  if recordObject.TableName = "" then return array(new pgdbconfRecord("No table name defined"))
		  if recordObject.key.Trim = "" then Return array(new pgdbconfRecord("Key should not be empty!"))
		  
		  dim rs as RecordSet
		  
		  dim output(-1) as pgdbconfRecord
		  dim record as pgdbconfRecord
		  
		  dim WHERE as string
		  WHERE = "language = " + if(recordObject.language.Trim = "" , "'" + DefaultLanguage + "'" , "'" + recordObject.language.Trim.Uppercase + "'") + " AND "
		  WHERE = WHERE + "application = " + if(recordObject.application.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.application.Trim.Uppercase + "'") + " AND "
		  WHERE = WHERE + "username = " + if(recordObject.user.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.user.Trim.Uppercase + "'") + " AND "
		  WHERE = WHERE + "section = " + if(recordObject.section.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.section.Trim.Uppercase + "'") + " AND "
		  WHERE = WHERE + "key = '" + recordObject.key.Trim.Uppercase + "'"
		  
		  rs = db.SQLSelect("SELECT * FROM " + recordObject.TableName + " WHERE " + WHERE + " ORDER BY language,application,username,section,key ASC")
		  if db.Error then Return array(new pgdbconfRecord("Error accessing settings file: " + db.ErrorMessage))
		  
		  if rs.RecordCount = 0 then // objdix does not exist
		    
		    return array(new pgdbconfRecord(false))
		    
		  else  // one or more records found
		    
		    while not rs.EOF
		      record = new pgdbconfRecord(true)
		      
		      record.language = rs.Field("language").StringValue
		      record.application = rs.Field("application").StringValue
		      record.user = rs.Field("username").StringValue
		      record.section = rs.Field("section").StringValue
		      record.key = rs.Field("key").StringValue
		      record.value = rs.Field("value").StringValue
		      record.comment = rs.Field("comment").StringValue
		      
		      output.Append record
		      
		      rs.MoveNext
		    wend
		    
		  end if
		  
		  Return output
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function pgdbconf_ReadSingle(extends db as PostgreSQLDatabase, recordObject as pgdbconfRecord) As pgdbconfRecord
		  // reads the first element that matches the (language/application/user/section/key) OR (objidx) criterion
		  // priority on objidx 
		  
		  if IsNull(recordObject) then Return new pgdbconfRecord("Invalid search parameters")
		  if recordObject.TableName = "" then Return new pgdbconfRecord("Table name not defined")
		  if validateSession(db) = false then Return new pgdbconfRecord("Database session is not valid")
		  
		  dim rs as RecordSet
		  dim output as pgdbconfRecord
		  
		  if recordObject.objidx <> "" then  // objidx is our match criterion
		    
		    rs = db.SQLSelect("SELECT * FROM " + recordObject.TableName + " WHERE objidx = '" + recordObject.objidx + "'")
		    if db.Error then Return new pgdbconfRecord("Error accessing settings table: " + db.ErrorMessage)
		    
		    if rs.RecordCount = 0 then // objdix does not exist
		      output = new pgdbconfRecord(false)
		      output.objidx = recordObject.objidx
		    else  // one record found (since we're looking for the primary key)
		      output = new pgdbconfRecord(true)
		    end if
		    
		    output.objidx = recordObject.objidx
		    
		  else // we look for the (language/application/user/section/key) combination
		    
		    if recordObject.key.Trim = "" then Return new pgdbconfRecord("Key should not be empty!")
		    
		    dim WHERE as string
		    WHERE = "language = " + if(recordObject.language.Trim = "" , "'" + DefaultLanguage + "'" , "'" + recordObject.language.Trim.Uppercase + "'") + " AND "
		    WHERE = WHERE + "application = " + if(recordObject.application.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.application.Trim.Uppercase + "'") + " AND "
		    WHERE = WHERE + "username = " + if(recordObject.user.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.user.Trim.Uppercase + "'") + " AND "
		    WHERE = WHERE + "section = " + if(recordObject.section.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.section.Trim.Uppercase + "'") + " AND "
		    WHERE = WHERE + "key = '" + recordObject.key.Trim.Uppercase + "'"
		    
		    rs = db.SQLSelect("SELECT * FROM " + recordObject.TableName + " WHERE " + WHERE + " ORDER BY language,application,username,section,key ASC")
		    if db.Error then Return new pgdbconfRecord("Error accessing settings file: " + db.ErrorMessage)
		    
		    if rs.RecordCount = 0 then // objdix does not exist
		      output = new pgdbconfRecord(false)
		    else  // one or more records found  (if it's an array it will return the first record and will not complain)
		      output = new pgdbconfRecord(true)
		      output.objidx = rs.Field("objidx").StringValue
		    end if
		    
		    
		  end if
		  
		  if output.Exists then
		    output.language = rs.Field("language").StringValue
		    output.application = rs.Field("application").StringValue
		    output.user = rs.Field("username").StringValue
		    output.section = rs.Field("section").StringValue
		    output.key = rs.Field("key").StringValue
		    output.value = rs.Field("value").StringValue
		    output.comment = rs.Field("comment").StringValue
		  end if
		  
		  Return output
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function pgdbconf_Upsert(extends db as PostgreSQLDatabase, recordObject as pgdbconfRecord) As pgdbconfRecord
		  // match criterion is either the (language/application/user/section/key) combination or objidx (only update)
		  // objidx holds priority
		  
		  if IsNull(recordObject) then Return new pgdbconfRecord("Invalid search parameters")
		  if recordObject.TableName = "" then Return new pgdbconfRecord("Table name not defined")
		  if validateSession(db) = false then Return new pgdbconfRecord("Database session is not valid")
		  
		  dim rs as RecordSet
		  dim WHERE as String
		  
		  
		  if recordObject.objidx <> "" then  // objidx is our match criterion -- it can only mean update
		    
		    rs = db.SQLSelect("SELECT * FROM " + recordObject.TableName + " WHERE objidx = '" + recordObject.objidx + "'")
		    if db.Error then Return new pgdbconfRecord("Error accessing settings table: " + db.ErrorMessage)
		    if rs.RecordCount = 0 then Return new pgdbconfRecord("Configuration record " + recordObject.objidx + " does not exist!")
		    
		    
		    db.SQLExecute("UPDATE " + recordObject.TableName + " SET value = '" + recordObject.value + "' , comment = '" + recordObject.comment + "' WHERE objidx = '" + recordObject.objidx + "'")
		    if db.Error then Return new pgdbconfRecord("Error updating settings file: " + db.ErrorMessage)
		    
		    db.Close
		    
		  else // we look for the (application/user/section/key) combination
		    
		    if recordObject.key.Trim = "" then Return new pgdbconfRecord("Key should not be empty!")
		    
		    select case db.Count(recordObject)
		    case -1  // error
		      Return new pgdbconfRecord("Error reading config table: " + mLastError)
		    case 0  // insert
		      
		      dim newRecord as new DatabaseRecord
		      
		      newRecord.Column("language") = if(recordObject.language.Trim = "" , DefaultLanguage , recordObject.language.Trim.Uppercase)
		      newRecord.Column("application") = if(recordObject.application.Trim = "" , GlobalName , recordObject.application.Trim.Uppercase)
		      newRecord.Column("username") = if(recordObject.user.Trim = "" , GlobalName , recordObject.user.Trim.Uppercase)
		      newRecord.Column("section") = if(recordObject.section.Trim = "" , GlobalName , recordObject.section.Trim.Uppercase)
		      newRecord.Column("key") = recordObject.key.Trim.Uppercase
		      
		      if recordObject.value <> "" then newRecord.Column("value") = recordObject.value
		      if recordObject.comment.Trim <> "" then newRecord.Column("comment") = recordObject.comment
		      
		      db.InsertRecord(recordObject.TableName , newRecord)
		      if db.Error then Return new pgdbconfRecord("Error writing settings table: " + db.ErrorMessage)
		      
		    case 1  // update
		      
		      WHERE = "language = " + if(recordObject.language.Trim = "" , "'" + DefaultLanguage + "'" , "'" + recordObject.language.Trim.Uppercase + "'") + " AND "
		      WHERE = WHERE + "application = " + if(recordObject.application.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.application.Trim.Uppercase + "'") + " AND "
		      WHERE = WHERE + "username = " + if(recordObject.user.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.user.Trim.Uppercase + "'") + " AND "
		      WHERE = WHERE + "section = " + if(recordObject.section.Trim = "" , "'" + GlobalName + "'" , "'" + recordObject.section.Trim.Uppercase + "'") + " AND "
		      WHERE = WHERE + "key = '" + recordObject.key.Trim.Uppercase + "'"
		      
		      db.SQLExecute("UPDATE " + recordObject.TableName + " SET value = '" + recordObject.value + "' , comment = '" + recordObject.comment + "' WHERE " + WHERE)
		      if db.Error then Return new pgdbconfRecord("Error updating settings table: " + db.ErrorMessage)
		      
		      db.Close
		      
		    else // it's an array --this method can't act on arrays
		      Return new pgdbconfRecord("Cannot use upsert on an array!")
		    end select
		    
		  end if
		  
		  recordObject.Error = False
		  
		  Return recordObject
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function validateSession(db as PostgreSQLDatabase) As Boolean
		  if IsNull(db) then 
		    
		    return false
		    
		  else
		    
		    Return true
		    
		  end if
		  
		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mLastError As string
	#tag EndProperty


	#tag Constant, Name = DefaultLanguage, Type = String, Dynamic = False, Default = \"DEFAULT", Scope = Private
	#tag EndConstant

	#tag Constant, Name = GlobalName, Type = String, Dynamic = False, Default = \"GLOBAL", Scope = Private
	#tag EndConstant


	#tag ViewBehavior
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
	#tag EndViewBehavior
End Module
#tag EndModule