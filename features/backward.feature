Feature: Data backward compatiblity
    The data scheme should be compatible between certain library versions.
    Some of the scenarios might be ignored and run only directly to
    indicate the incompatiblities.
  Background:
    Given the library works in development mode

  @ignore
  Scenario: compatiblity with version 0.7.0
      To make the data compatible, the 'options' key should be removed from 
      the database.yml
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    And a class Caveman has an age field of type integer
    And a class Caveman has an identifier field of type ulong
    And a class Caveman has a height field of type float
    And a class Caveman has a account_balance field of type float
    And a class Automobile has a name field of type string
    And a class Caveman has one automobile
    And a class Dog has a nickname field of type string
    And a class Caveman has many dogs
    When I open the database for reading in data/backward/0.7.0
    Then there should be 1 Caveman
    And there should be 1 Dog
    And there should be 1 Automobile
    And the name of the first Caveman should be 'Fred'
    And the age of the first Caveman should be '25'
    And the identifier of the first Caveman should be '111222333'
    And the height of the first Caveman should be '1.86'
    And the account_balance of the first Caveman should be '-0.00000001'
    And the automobile of the first Caveman should be equal to the first Automobile persisted
    And the first of dogs of the first Caveman should be equal to the first Dog persisted
