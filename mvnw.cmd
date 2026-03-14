@REM ----------------------------------------------------------------------------
@REM Licensed to the Apache Software Foundation (ASF) under one
@REM or more contributor license agreements.  See the NOTICE file
@REM distributed with this work for additional information
@REM regarding copyright ownership.  The ASF licenses this file
@REM to you under the Apache License, Version 2.0 (the
@REM "License"); you may not use this file except in compliance
@REM with the License.  You may obtain a copy of the License at
@REM
@REM    https://www.apache.org/licenses/LICENSE-2.0
@REM
@REM Unless required by applicable law or agreed to in writing,
@REM software distributed under the License is distributed on an
@REM "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
@REM KIND, either express or implied.  See the License for the
@REM specific language governing permissions and limitations
@REM under the License.
@REM ----------------------------------------------------------------------------

@REM ----------------------------------------------------------------------------
@REM Apache Maven Wrapper startup batch script, version 3.2.0
@REM ----------------------------------------------------------------------------

@IF "%__MVNW_ARG0_NAME__%"=="" (SET "BASE_DIR=%~dp0") ELSE (SET "BASE_DIR=%__MVNW_ARG0_NAME__%")
@SET MAVEN_PROJECTBASEDIR=%BASE_DIR%

@IF NOT "%MAVEN_WRAPPER_PROPERTIES_FILE%" == "" GOTO wrapper_properties_file_location_done
@SET MAVEN_WRAPPER_PROPERTIES_FILE=%BASE_DIR%.mvn\wrapper\maven-wrapper.properties
:wrapper_properties_file_location_done

@FOR /F "usebackq tokens=1,2 delims==" %%A IN ("%MAVEN_WRAPPER_PROPERTIES_FILE%") DO (
    @IF "%%A"=="distributionUrl" SET DISTRIBUTION_URL=%%B
)

@FOR /F %%A IN ('powershell -Command "[System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)"') DO (
    @SET LOCAL_APP_DATA=%%A
)

@SET MAVEN_USER_HOME=%LOCAL_APP_DATA%\apache-maven
@SET DISTRIBUTION_FILE_NAME=%DISTRIBUTION_URL:*/=%
@FOR /F "tokens=* delims=" %%A IN ("%DISTRIBUTION_FILE_NAME%") DO SET DISTRIBUTION_FILE_NAME=%%~nA
@SET DISTRIBUTION_DIR_NAME=%DISTRIBUTION_FILE_NAME:-bin=%
@SET MAVEN_HOME=%MAVEN_USER_HOME%\%DISTRIBUTION_DIR_NAME%

@IF EXIST "%MAVEN_HOME%\bin\mvn.cmd" GOTO execute_maven

@ECHO Downloading Maven...
@powershell -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DISTRIBUTION_URL%' -OutFile '%TEMP%\maven.zip' }"
@ECHO Extracting Maven...
@powershell -Command "& { Expand-Archive -Path '%TEMP%\maven.zip' -DestinationPath '%MAVEN_USER_HOME%' -Force }"
@DEL "%TEMP%\maven.zip"
@ECHO Maven downloaded successfully.

:execute_maven
@SET "JAVA_HOME=%JAVA_HOME%"
@"%MAVEN_HOME%\bin\mvn.cmd" %*
